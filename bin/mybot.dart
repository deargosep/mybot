import 'package:hive/hive.dart';
import 'package:ollama_dart/ollama_dart.dart' as ollama;
import 'package:televerse/telegram.dart';
import 'package:televerse/televerse.dart';

import 'package:dotenv/dotenv.dart';

void main() async {
  final client = ollama.OllamaClient();

  var env = DotEnv(includePlatformEnvironment: true)..load();
  if (!env.isDefined('TOKEN')) {
    throw Exception(".env is not populated");
  }
  final String username = env['USERNAME']!;
  final String token = env['TOKEN']!;
  final String model = env['MODEL']!;

  final bot = Bot(token);
  Hive.init('./history');
  Box box = await Hive.openBox('history');

  bot.onMessage((ctx) async {
    if (ctx.message != null && ctx.message!.text != null) {
      if (ctx.message!.text!.contains(username) ||
          ctx.message?.replyToMessage?.from?.username == username) {
        bot.api.sendChatAction(ID.create(ctx.chat?.id), ChatAction.typing);
        List<Map<String, dynamic>>? chatContextRaw =
            await box.get(ctx.chat?.id);
        List<ollama.Message> chatContext = [];
        if (chatContextRaw != null) {
          chatContext = [
            ...chatContextRaw.map((e) => ollama.Message.fromJson(e))
          ];
        }
        final generated = await client.generateChatCompletion(
            request:
                ollama.GenerateChatCompletionRequest(model: model, messages: [
          ...chatContext,
          ollama.Message(
              role: ollama.MessageRole.user, content: ctx.message!.text!)
        ]));
        if (generated.message != null) {
          await box.put("${ctx.chat?.id}", [
            ...chatContext.map((e) => e.toJson()),
            generated.message!.toJson()
          ]);
          ctx.reply(generated.message!.content,
              replyParameters:
                  ReplyParameters(messageId: ctx.message!.messageId));
        }
        print(generated.message?.content);
      }
    }
  });
  bot.start();
}

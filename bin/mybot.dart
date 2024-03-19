import 'package:hive/hive.dart';
import 'package:ollama_dart/ollama_dart.dart' as ollama;
import 'package:televerse/telegram.dart';
import 'package:televerse/televerse.dart';

import 'package:dotenv/dotenv.dart';
import 'package:translator/translator.dart';

void main() async {
  final client = ollama.OllamaClient();
  final translator = GoogleTranslator();

  var env = DotEnv(includePlatformEnvironment: true)..load();
  if (!env.isDefined('TOKEN')) {
    throw Exception(".env is not populated");
  }
  final String username = env['USERNAME']!;
  final String token = env['TOKEN']!;
  final String model = env['MODEL']!;

  final bot = Bot(token);
  Hive.init('./history');
  bot.command('clean', (ctx) {
    Hive.openBox(ctx.chat!.id.toString()).then((value) {
      value.put('history', []);
      ctx.reply('Cleaned',
          replyParameters: ReplyParameters(messageId: ctx.message!.messageId));
    });
  });

  bot.onMessage((ctx) async {
    Box box = await Hive.openBox(ctx.chat!.id.toString());
    if (ctx.message != null && ctx.message!.text != null) {
      var message = ctx.message!;
      var chat = ctx.chat!;
      var text = ctx.message!.text!;
      if ((message.text!.contains(username) ||
              message.replyToMessage?.from?.username == username) ||
          chat.type == ChatType.private) {
        bot.api.sendChatAction(ID.create(chat.id), ChatAction.typing);
        List<Map<String, dynamic>>? chatContextRaw = await box.get(chat.id);
        List<ollama.Message> chatContext = [];
        if (chatContextRaw != null) {
          chatContext = [
            ...chatContextRaw.map((e) => ollama.Message.fromJson(e))
          ];
        }

        final input = text;

        var translated =
            await translator.translate(input, from: 'ru', to: 'en');
        final generated = await client.generateChatCompletion(
            request:
                ollama.GenerateChatCompletionRequest(model: model, messages: [
          ...chatContext,
          ollama.Message(
              role: ollama.MessageRole.user, content: translated.text)
        ]));
        if (generated.message != null) {
          await box.put('history', [
            ...chatContext.map((e) => e.toJson()),
            generated.message!.toJson()
          ]);
          ctx.reply(generated.message!.content,
              replyParameters: ReplyParameters(messageId: message.messageId));
        }
        print(
            '<---User ${message.from!.firstName} @${message.from!.username ?? ''}--->');
        print(translated.text);
        print('<---User---/>');
        print('');
        print('<---AI--->');
        print(generated.message?.content);
        print('<---AI---/>');
        print('');
      }
    }
  });
  bot.start();
}

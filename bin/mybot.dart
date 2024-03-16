import 'package:hive/hive.dart';
import 'package:ollama_dart/ollama_dart.dart' as ollama;
import 'package:televerse/telegram.dart';
import 'package:televerse/televerse.dart';

/// This is a general example of how to use the Televerse library.
void main() async {
  final client = ollama.OllamaClient();
  // Set the OpenAI API key from the .env file.
  /// Get the bot token from the environment
  final String token = "5040632554:AAGWXE2qdxtsTZfZmt7Iw87X-XjLenMwg6A";

  /// Create a new bot instance
  final bot = Bot(token);
  Hive.init('./history');
  Box box = await Hive.openBox('history');

  bot.onMessage((ctx) async {
    if (ctx.message != null && ctx.message!.text != null) {
      if (ctx.message!.text!.contains('furry_entertainment_bot') ||
          ctx.message?.replyToMessage?.from?.username ==
              'furry_entertainment_bot') {
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
            request: ollama.GenerateChatCompletionRequest(
                model: 'openhermes:latest',
                messages: [
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
        // Printing the output to the console
        print(generated.message?.content);
      }
    }
  });
  bot.start();
}

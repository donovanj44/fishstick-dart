import "dart:async";
import "dart:math";
import "package:numeral/numeral.dart";
import "package:logging/logging.dart";
import "package:nyxx/nyxx.dart";
import "package:nyxx_commands/nyxx_commands.dart";

import "../extensions/context_extensions.dart";
import "../database/database.dart";
// import "../database/database_user.dart";
// import "../database/database_guild.dart";
import "../config.dart";
import "../utils/utils.dart";

class Client {
  /// Configuration for the client
  late final Config config = Config();

  /// logger
  final Logger logger = Logger("BOT");

  /// The nyxx client
  late INyxxWebsocket bot;

  /// The database for the bot
  late Database database;

  /// Commands for the client
  late CommandsPlugin commands;

  // Footer text
  String footerText = "discord.gg/fishstick";

  Client() {
    /// setup logger
    Logger.root.level = Level.INFO;

    /// setup commands
    commands = CommandsPlugin(
      prefix: (_) => ".",
      guild: config.developmentMode ? Snowflake(config.developmentGuild) : null,
      options: CommandsOptions(
        logErrors: true,
        acceptBotCommands: false,
        acceptSelfCommands: false,
        autoAcknowledgeInteractions: true,
        hideOriginalResponse: false,
      ),
    );

    /// dispose command cache
    commands.onPostCall.listen((ctx) {
      ctx.disposeCache();
    });

    /// listen for commands error and handle them
    commands.onCommandError.listen((exception) async {
      if (exception is CommandNotFoundException) {
        return;
      }

      if (exception is CommandInvocationException) {
        exception.context.disposeCache();
      }

      if (exception is CheckFailedException) {
        switch (exception.failed.name) {
          case "blacklist-check":
            if (exception.context is InteractionContext) {
              await (exception.context as InteractionContext).respond(
                MessageBuilder.content(
                    "You are blacklisted from using the bot!"),
                hidden: true,
              );
            } else {
              await exception.context.respond(
                MessageBuilder.content(
                    "You are blacklisted from using the bot!"),
              );
            }
            break;

          case "premium-check":
            break;

          case "partner-check":
            if (exception.context is InteractionContext) {
              await (exception.context as InteractionContext).respond(
                MessageBuilder.content(
                    "You need Fishstick partner to use this command.\nDM Vanxh#6969 for more info."),
                hidden: true,
              );
            } else {
              await exception.context.respond(
                MessageBuilder.content(
                    "You need Fishstick partner to use this command.\nDM Vanxh#6969 for more info."),
              );
            }
            break;

          case "cooldown-check":
            break;

          default:
            logger.shout("Unhandled check exception: ${exception.failed.name}");
            break;
        }
      } else {
        List<String> errorTitles = [
          "💥 Uh oh! That was unexpected!",
          "⚠️ Not the LLAMA you're looking for!",
          "⚠️ There was an error!",
        ];
        if (exception is CommandInvocationException) {
          final EmbedBuilder errorEmbed = EmbedBuilder()
            ..title = errorTitles[Random().nextInt(errorTitles.length)]
            ..color = DiscordColor.red
            ..timestamp = DateTime.now()
            ..footer =
                (EmbedFooterBuilder()..text = exception.runtimeType.toString())
            ..description =
                "An error has occurred!\nYou can join our [support server](${config.supportServer}) to report the bug if you feel its a bug."
            ..addField(
              name: "Error",
              content: exception.message,
            );

          if (exception.context is InteractionContext) {
            await (exception.context as InteractionContext).respond(
              MessageBuilder.embed(errorEmbed),
              hidden: true,
            );
          } else {
            await exception.context.respond(
              MessageBuilder.embed(errorEmbed),
            );
          }
        } else {
          logger.shout("Unhandled exception type: ${exception.runtimeType}");
        }
      }
    });

    /// user blacklist check for commands
    commands.check(
      Check((ctx) async => !(await ctx.dbUser).isBanned, "blacklist-check"),
    );

    /// cooldown check for commands
    // commands.check(
    //   CooldownCheck(CooldownType.user, Duration(seconds: 5), 2),
    // ); // temporary cooldown system

    commands.check(Check.any([
      Check.all([
        premiumCheck,
        CooldownCheck(CooldownType.user, Duration(seconds: 5), 4),
      ]),
      Check.all([
        Check.deny(premiumCheck),
        CooldownCheck(CooldownType.user, Duration(seconds: 5), 2),
      ]),
    ]));

    /// setup discord client
    bot = NyxxFactory.createNyxxWebsocket(
      config.token,
      GatewayIntents.allUnprivileged,
      options: ClientOptions(
        initialPresence: PresenceBuilder.of(
          activity: ActivityBuilder.game("/help"),
          status: UserStatus.online,
        ),
        dispatchRawShardEvent: true,
      ),
      useDefaultLogger: false,
    )
      ..registerPlugin(Logging())
      ..registerPlugin(CliIntegration())
      ..registerPlugin(IgnoreExceptions())
      ..registerPlugin(commands);

    bot.onReady.listen((_) {
      Timer.periodic(Duration(minutes: 1), (timer) {
        bot.setPresence(
          PresenceBuilder.of(
            activity: ActivityBuilder.game(
                "/help | ${Numeral(bot.guilds.length).value()} Guilds"),
            status: UserStatus.online,
          ),
        );
      });
    });

    /// setup database
    database = Database(this);
  }

  /// Start the client.
  /// This will connect to the bot to discord and database.
  Future<void> start() async {
    int start;

    start = DateTime.now().millisecondsSinceEpoch;
    await bot.connect();
    logger.info(
        "Connected to discord [${(DateTime.now().millisecondsSinceEpoch - start).toStringAsFixed(2)}ms]");

    start = DateTime.now().millisecondsSinceEpoch;
    await database.connect();
    logger.info(
        "Connected to database [${(DateTime.now().millisecondsSinceEpoch - start).toStringAsFixed(2)}ms]");
  }
}

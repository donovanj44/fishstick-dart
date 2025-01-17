import "dart:async";
import "package:logging/logging.dart";

import "package:nyxx/nyxx.dart";
import "package:nyxx_commands/nyxx_commands.dart";
// import "package:nyxx_sharding/nyxx_sharding.dart";

/// telegram bot
import "../telegram/telegram.dart";

import "../database/database.dart";
import "../config.dart";

import "../utils/utils.dart";
import "../utils/commands_handler.dart";

import "../system_jobs/system_jobs.dart";

import "../commands/info/ping.dart";
import "../commands/info/invite.dart";
import "../commands/info/info.dart";
import "../commands/info/help.dart";
import "../commands/autopost_stw_alerts/autopost.dart";
import "../commands/general/color.dart";
import "../commands/general/settings.dart";
import "../commands/premium/premium.dart";
import "../commands/partner/partner.dart";
import "../commands/blacklist/blacklist.dart";
import "../commands/fortnite/account/login/login.dart";
import "../commands/fortnite/account/lx.dart";
import "../commands/fortnite/account/logout.dart";
import "../commands/fortnite/account/account.dart";
import "../commands/fortnite/account/launch.dart";
import "../commands/fortnite/account/be_eac.dart";
import "../commands/fortnite/vbucks/vbucks.dart";
import "../commands/fortnite/sac/sac.dart";
import "../commands/fortnite/mfa/mfa.dart";
import "../commands/fortnite/afk.dart";
import "../commands/fortnite/overview/overview.dart";
// import "../commands/fortnite/locker/locker.dart";
// import "../commands/fortnite/stw/resources.dart";
// import "../commands/fortnite/stw/skip_tutorial.dart";
// import "../commands/fortnite/stw/homebase_name.dart";
// import "../commands/fortnite/stw/upgrade.dart";
// import "../commands/fortnite/stw/storm_king.dart";
// import "../commands/fortnite/stw/pending_difficulty_rewards.dart";
// import "../commands/fortnite/stw/survivor_squad_presets/survivor_squad_presets.dart";
// import "../commands/fortnite/stw/daily.dart";
// import "../commands/fortnite/stw/dupe.dart";
// import "../commands/fortnite/stw/transfer.dart";
// import "../commands/fortnite/stw/hero_loadout/hero_loadout.dart";
// import "../commands/fortnite/stw/xpboost/xpboost.dart";
// import "../commands/fortnite/stw/inventory/inventory.dart";
// import "../commands/fortnite/stw/research/research.dart";
import "../commands/fortnite/shop/shop.dart";
import "../commands/fortnite/buy/buy.dart";
import "../commands/fortnite/buy/gift.dart";
import "../commands/fortnite/friends/friends.dart";

typedef NullableString = String;
typedef NullableIUser = IUser;
typedef NullableIRole = IRole;

class Client {
  /// Configuration for the client
  late final Config config = Config();

  /// logger
  final Logger logger = Logger("BOT");

  /// The nyxx client
  late final INyxxWebsocket bot;

  /// home [IGuild]
  late final IGuild homeGuild;

  /// Telegram bot client
  late final TeleBotClient telebot;

  /// The database for the bot
  late final Database database;

  /// Cached cosmetics for the client
  List<Map<String, dynamic>> cachedCosmetics = [];

  /// System jobs manager
  late final SystemJobsPlugin systemJobs;

  /// Sharding plugin
  // late final IShardingPlugin shardingPlugin;

  // Footer text
  String footerText = "discord.gg/fishstick";

  /// prefix for commands
  String prefix = ".";

  /// global commands cooldown
  int commandsCooldown = 3;

  Client() {
    /// setup logger
    Logger.root.level = Level.INFO;

    /// setup logging
    Logger.root.onRecord.listen((LogRecord rec) {
      String msg =
          "[${rec.time}] [${rec.level.name}] [${rec.loggerName}] ${rec.message}";

      // ignore: avoid_print
      print(msg);
    });

    /// setup system jobs manager
    systemJobs = SystemJobsPlugin(this);

    /// setup commands
    final CommandsPlugin _commands = CommandsPlugin(
      prefix: dmOr((_) => "fishstickbot."),
      guild: config.developmentMode ? Snowflake(config.developmentGuild) : null,
      options: CommandsOptions(
        logErrors: true,
        acceptBotCommands: false,
        acceptSelfCommands: false,
        autoAcknowledgeInteractions: true,
      ),
    );

    /// setup converters
    _commands.addConverter(_commands.getConverter(NullableString,
        logWarn: false) as Converter<String?>);
    _commands.addConverter(_commands.getConverter(NullableIUser, logWarn: false)
        as Converter<IUser?>);
    _commands.addConverter(_commands.getConverter(NullableIRole, logWarn: false)
        as Converter<IRole?>);

    /// register the commands
    _commands.addCommand(pingCommand);
    _commands.addCommand(inviteCommand);
    _commands.addCommand(infoCommand);
    _commands.addCommand(helpCommand);
    _commands.addCommand(autopostCommand);
    _commands.addCommand(colorCommand);
    _commands.addCommand(settingsCommand);
    _commands.addCommand(premiumCommand);
    _commands.addCommand(partnerCommand);
    _commands.addCommand(blacklistCommand);
    _commands.addCommand(loginCommand);
    _commands.addCommand(lxCommand);
    _commands.addCommand(logoutCommand);
    _commands.addCommand(accountCommand);
    _commands.addCommand(gameLaunchCommand);
    _commands.addCommand(beeacCommand);
    _commands.addCommand(vbucksCommand);
    _commands.addCommand(affiliateCommand);
    _commands.addCommand(mfaCommand);
    _commands.addCommand(afkCommand);
    _commands.addCommand(overviewCommand);
    // _commands.addCommand(resourcesSTWCommand);
    // _commands.addCommand(lockerCommand);
    // _commands.addCommand(skipTutorialCommand);
    // _commands.addCommand(homebaseNameCommand);
    // _commands.addCommand(stwUpgradeCommand);
    // _commands.addCommand(mskCommand);
    // _commands.addCommand(pendingDifficultyRewardsCommand);
    // _commands.addCommand(survivorSquadPresetCommand);
    // _commands.addCommand(claimDailyCommand);
    // _commands.addCommand(dupeCommand);
    // _commands.addCommand(transferCommand);
    // _commands.addCommand(heroLoadoutCommand);
    // _commands.addCommand(xpBoostCommand);
    // _commands.addCommand(inventoryCommand);
    // _commands.addCommand(stwResearchCommand);
    _commands.addCommand(shopCommand);
    _commands.addCommand(buyCommand);
    _commands.addCommand(giftCommand);
    _commands.addCommand(friendsCommand);

    /// handle commands error
    handleCommandsError(this, _commands);

    /// handle commands check
    handleCommandsCheckHandler(_commands, commandsCooldown);

    /// handle commands post call
    handleCommandsPostCall(_commands);

    /// setup sharding plugin
    // shardingPlugin = IShardingPlugin();

    /// setup database
    database = Database(config.mongoUri);

    /// setup discord client
    bot = NyxxFactory.createNyxxWebsocket(
      config.token,
      GatewayIntents.allUnprivileged)
      // activity: ActivityBuilder.game("Claiming rewards"),
      // status:UserStatus.online,
      // messageCacheSize: 0,
      // guildSubscriptions: false,
      // options: getOptions(
      //   ClientOptions(
      //     initialPresence: PresenceBuilder.of(
      //       activity: ActivityBuilder.game("/help | shards"),
      //       status: UserStatus.online,
      //     ),
      //     messageCacheSize: 0,
      //     guildSubscriptions: false,
      //     // dispatchRawShardEvent: true,
      //   ),
      // ),
    
      ..registerPlugin(CliIntegration())
      ..registerPlugin(IgnoreExceptions())
      ..registerPlugin(_commands)
      // ..registerPlugin(shardingPlugin)
      ..registerPlugin(systemJobs);

    telebot = TeleBotClient(this);

    return;
  }

  /// Start the client.
  /// This will connect to the bot to discord and database.
  Future<void> start() async {
    int _start;

    _start = DateTime.now().millisecondsSinceEpoch;
    await database.connect();
    logger.info(
        "Connected to database [${(DateTime.now().millisecondsSinceEpoch - _start).toStringAsFixed(2)}ms]");

    _start = DateTime.now().millisecondsSinceEpoch;
    await bot.connect();
    logger.info(
        "Connected to discord [${(DateTime.now().millisecondsSinceEpoch - _start).toStringAsFixed(2)}ms]");

    try {
      homeGuild = await bot.fetchGuild(config.supportServerId.toSnowflake());
    } catch (e) {
      // IGNORE
    }

    // if (shardIds.contains(0)) {
    //   _start = DateTime.now().millisecondsSinceEpoch;
    //   await telebot.connect();
    //   logger.info(
    //       "Connected to telegram [${(DateTime.now().millisecondsSinceEpoch - _start).toStringAsFixed(2)}ms]");
    // } else {
    //   logger.info(
    //       "Current process dont have shard 0, skipping telegram connection.");
    // }

    return;
  }

  /// encrypt a string
  String encryptString(String text) => encrypt(text);

  /// decrypt a string
  String decryptString(String text) => decrypt(text);
}

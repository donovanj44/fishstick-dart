import "private.dart";

class Config {
  static final bool _developmentMode = false;

  /// is the bot in development mode
  bool get developmentMode => _developmentMode;

  /// guild id to register commands on while in development mode.
  String get developmentGuild => "756720238631845967";

  /// the bot's owner id
  String get ownerId => "203306017566490625";

  /// the bot's telegram owner id
  String get telegramOwnerId => "1784287150";

  /// support server invite
  String get supportServer => "https://discord.gg/fishstick";

  /// support server id
  String get supportServerId => "797736897941995540";

  /// support server premium role id
  String get supportServerPremiumRoleId => "756720238640365575";

  /// encryption key
  String get encryptionKey => Privates.encryptionKey;

  /// api key for backend
  // String get apiKey => Privates.apiKey;

  /// webhook key for backend
  // String get webhookKey => Privates.webhookKey;

  /// topgg api key
  // String get topggApiKey => Privates.topGGApiKey;

  /// the bot's token
  String get token =>
      _developmentMode ? Privates.discordDevToken : Privates.discordProdToken;

  /// telegram bot token
  String get telegramToken =>
      _developmentMode ? Privates.telegramDevToken : Privates.teleToken;

  /// mongo db uri
  String get mongoUri => Privates.mongoDbUri;
}

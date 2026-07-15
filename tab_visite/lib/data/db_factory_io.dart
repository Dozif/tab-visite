// Mobile/desktop : sqflite utilise sa factory native par défaut, rien à
// configurer ici. (Les tests sur la VM Dart posent eux-mêmes
// `databaseFactory = databaseFactoryFfi`.)
void configureDatabaseFactory() {}

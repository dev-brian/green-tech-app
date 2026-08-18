/// Estado global simple de arranque de la app.
///
/// Se separa de main.dart para que las pantallas puedan consultarlo sin
/// tener que importar el archivo de entrada de la app.
library;

/// true si Firebase quedó listo para usarse (google-services.json /
/// GoogleService-Info.plist configurados y `Firebase.initializeApp()`
/// no lanzó error). Mientras conectas tu proyecto real, esto queda en
/// false y la app sigue funcionando en modo local (ver el botón
/// "Continuar sin cuenta" en LoginScreen).
bool firebaseReady = false;

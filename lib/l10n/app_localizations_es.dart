// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Limpiador de Galería';

  @override
  String get settings => 'Configuración';

  @override
  String get theme => 'Tema';

  @override
  String get light => 'Claro';

  @override
  String get dark => 'Oscuro';

  @override
  String get system => 'Sistema';

  @override
  String get language => 'Idioma';

  @override
  String get turkish => 'Turco';

  @override
  String get english => 'Inglés';

  @override
  String get spanish => 'Español';

  @override
  String get galleryPermissionRequired => 'Se requiere permiso de galería.';

  @override
  String get grantPermission => 'Conceder Permiso';

  @override
  String get folderTargets => 'Carpetas Objetivo';

  @override
  String get history => 'Historial';

  @override
  String get swipeLeftToDelete => 'Deslizar izquierda: Eliminar';

  @override
  String get swipeRightToKeep => 'Deslizar derecha: Mantener';

  @override
  String get noPhotosToShow => 'No hay fotos para mostrar.';

  @override
  String get selectAlbum => 'Seleccionar Álbum';

  @override
  String get selectAlbumToView => 'Seleccionar Álbum para Ver';

  @override
  String get allPhotos => 'Todas las Fotos';

  @override
  String get changeAlbum => 'Cambiar Álbum';

  @override
  String get dragPhotoHere => 'Arrastra la foto aquí';

  @override
  String get albumNotFound => 'Álbum no encontrado';

  @override
  String movingToAlbum(String album) {
    return 'Moviendo a $album...';
  }

  @override
  String movedToAlbum(String album) {
    return 'Movido a $album';
  }

  @override
  String get moveToAlbumFailed =>
      'Error al mover al álbum. Por favor, inténtalo de nuevo.';

  @override
  String deleteCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    return '$countString Eliminar';
  }

  @override
  String deletePhotos(int count) {
    return 'Eliminar Fotos ($count)';
  }

  @override
  String get applyDeletions => 'Aplicar Eliminaciones';

  @override
  String get undo => 'Deshacer';

  @override
  String get deleteLimitTitle => 'Límite de 100 Fotos para Eliminar';

  @override
  String get dailyDeleteLimit => 'Tu límite diario de eliminación: 100 fotos';

  @override
  String get undoAll => 'Deshacer Todo';

  @override
  String get historyAndQueue => 'Estadísticas';

  @override
  String get noHistoryYet => 'Aún no hay historial.';

  @override
  String get keep => 'MANTENER';

  @override
  String get delete => 'ELIMINAR';

  @override
  String get move => 'MOVER';

  @override
  String get pending => 'Pendiente';

  @override
  String get applied => 'Aplicado';

  @override
  String get undone => 'Deshecho';

  @override
  String get undoAllButton => 'Deshacer Todo';

  @override
  String deletedSuccessfully(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    return '$countString fotos eliminadas exitosamente.';
  }

  @override
  String get success => '¡Éxito!';

  @override
  String get ok => 'Aceptar';

  @override
  String get startCleaning => 'Comienza a\nlimpiar tu galería';

  @override
  String get swipeCardsDescription =>
      'Desliza las tarjetas a la derecha: Mantener • izquierda: Eliminar. Arrastra a los objetivos superiores para mover a carpetas.';

  @override
  String get quickSwipe => 'Deslizamiento rápido';

  @override
  String get dragToFolder => 'Arrastrar a carpeta';

  @override
  String get undoSafety => 'Seguridad de deshacer';

  @override
  String get galleryInfo => 'Información de Galería';

  @override
  String get album => 'Álbum';

  @override
  String get photoVideo => 'Fotos y Videos';

  @override
  String get totalSize => 'Tamaño Total';

  @override
  String get galleryInfoLoading => 'Cargando información de galería...';

  @override
  String get loadingMayTakeFewSeconds =>
      'Este proceso puede tardar unos segundos, por favor espera';

  @override
  String get galleryInfoNotAvailable => 'Información de galería no disponible';

  @override
  String get tryAgain => 'Intentar de Nuevo';

  @override
  String get startCleaningButton => 'Comenzar a Limpiar';

  @override
  String get loading => 'Cargando...';

  @override
  String get galleryInfoNotLoaded =>
      'No se pudo cargar la información de la galería';

  @override
  String get grantPermissionToStart =>
      'Concede permiso de acceso a fotos para comenzar';

  @override
  String get start => 'Comenzar';

  @override
  String get managePermissionsInSettings =>
      'Gestionar Permisos en Configuración';

  @override
  String get iosDeleteNote =>
      'En iOS, las eliminaciones se mueven a \"Eliminados Recientes\" y se pueden recuperar dentro de 30 días.';

  @override
  String get swipeLeftToDeleteTitle =>
      'Deslizar Izquierda para Eliminar,\nDeslizar Derecha para Mantener';

  @override
  String get swipeLeftToDeleteDescription =>
      'Revisa rápidamente tus fotos deslizando las tarjetas a la izquierda o derecha. Desliza a la derecha para mantener, desliza a la izquierda para eliminar.';

  @override
  String get organizeAlbumsTitle => 'Organiza tus\nÁlbumes';

  @override
  String get organizeAlbumsDescription =>
      'Arrastra tus fotos a los álbumes superiores para organizarlas. Organiza tus carpetas y mueve tus fotos donde quieras.';

  @override
  String get deleteUselessPhotosTitle => 'Elimina Fotos Inútiles\ny Malas';

  @override
  String get deleteUselessPhotosDescription =>
      'Elimina fotos borrosas, tomadas incorrectamente o innecesarias para liberar espacio en tu teléfono. Limpia tu almacenamiento y crea más espacio.';

  @override
  String get skip => 'Saltar';

  @override
  String get continueButton => 'Continuar';

  @override
  String get startButton => 'Comenzar';

  @override
  String get galleryPermission => 'Permiso de Galería';

  @override
  String get photoLibraryAccessRequired =>
      'Se requiere acceso a la biblioteca de fotos';

  @override
  String get permissionRequestDescription =>
      'Necesitamos acceso a tus fotos para organizar con deslizamiento. Puedes gestionar esto en cualquier momento desde la configuración.';

  @override
  String get allowAccess => 'Permitir Acceso';

  @override
  String get openSettings => 'Abrir Configuración';

  @override
  String get checkAgain => 'Verificar de Nuevo';

  @override
  String get weNeedYourAccess => 'Necesitamos tu acceso';

  @override
  String get recentlyDeleted => 'Fotos Eliminadas Recientemente';

  @override
  String get restorePhoto => 'Restaurar Foto';

  @override
  String get restorePhotoMessage =>
      'Esta foto será restaurada. ¿Deseas continuar?';

  @override
  String get cancel => 'Cancelar';

  @override
  String get restore => 'Restaurar';

  @override
  String get photoRestored => 'Foto restaurada';

  @override
  String get remainingDeletionRights => 'Derechos de Eliminación Restantes';

  @override
  String get watchAdToEarn => 'Ver Anuncio';

  @override
  String get earnDeletionRights => '+20 Eliminaciones';

  @override
  String get adNotReady =>
      'El anuncio aún no está listo. Por favor, inténtalo de nuevo en unos segundos.';

  @override
  String get earnedDeletionRights => '¡Ganaste 20 derechos de eliminación!';

  @override
  String get goPremium => 'Hazte Premium';

  @override
  String get premiumTitle => 'Hazte Premium';

  @override
  String get premiumDescription =>
      '¡Obtén derechos de eliminación ilimitados y acceso a todas las funciones con la membresía Premium!';

  @override
  String get premiumFeatures => 'Características Premium';

  @override
  String get unlimitedDeletions => 'Derechos de eliminación ilimitados';

  @override
  String get noAds => 'Experiencia sin anuncios';

  @override
  String get prioritySupport => 'Soporte prioritario';

  @override
  String get upgradeNow => 'Actualizar Ahora';

  @override
  String get maybeLater => 'Tal Vez Más Tarde';

  @override
  String get buyUnlimitedRights => 'Comprar Derechos Ilimitados';

  @override
  String get oneTimePayment => 'Pago Único';

  @override
  String get noMoreAds => 'Sin más anuncios';

  @override
  String get lifetimeAccess => 'Acceso de por vida';

  @override
  String get purchaseNow => 'Comprar Ahora';
}

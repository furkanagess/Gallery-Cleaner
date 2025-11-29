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
  String get selectAlbumToView => 'Selecciona el álbum que deseas ver';

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
  String get noHistoryYet => 'Aún No Hay Estadísticas';

  @override
  String get noHistoryYetDescription =>
      'Comienza a revisar y organizar tus fotos para ver tu actividad y estadísticas aquí.';

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
  String get adNotReady => 'Cargando Anuncio...';

  @override
  String get earnDeletionRights => '+20 Eliminaciones';

  @override
  String get watchAdAndEarnDeletionRights => '+20 Eliminaciones';

  @override
  String get galleryPermissionDescription =>
      'Necesitamos acceso a tus fotos y videos para realizar operaciones de limpieza de galería.';

  @override
  String get quickCleanupTitle => 'Limpieza Rápida';

  @override
  String get quickCleanupDescription => 'Revisa rápidamente tus fotos';

  @override
  String get organizeTitle => 'Organizar';

  @override
  String get organizeDescription => 'Mueve y organiza en tus álbumes';

  @override
  String get safeDeleteTitle => 'Eliminación Segura';

  @override
  String get safeDeleteDescription => 'Limpia fotos innecesarias';

  @override
  String get increaseDeletionRights => 'Aumentar Derechos de Eliminación';

  @override
  String get increaseScanRights => 'Aumentar Derechos de Escaneo';

  @override
  String earnDeleteRights(int amount) {
    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '+$amountString Eliminaciones';
  }

  @override
  String earnScanRights(int amount) {
    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '+$amountString Escaneos';
  }

  @override
  String get earnedDeletionRights => '¡Ganaste 20 derechos de eliminación!';

  @override
  String get goPremium => 'Hazte Premium';

  @override
  String get premiumTitle => 'Hazte Premium';

  @override
  String get unlockPremiumFeatures => 'Desbloquea Funciones Premium';

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
  String get buyUnlimitedBlurRights => 'Comprar Blur Ilimitado';

  @override
  String get buyUnlimitedDuplicateRights => 'Comprar Duplicados Ilimitados';

  @override
  String get unlimitedBlurScans =>
      'Escaneos de Blur Ilimitados • Acceso de por Vida';

  @override
  String get unlimitedDuplicateScans =>
      'Escaneos de Duplicados Ilimitados • Acceso de por Vida';

  @override
  String get oneTimePayment => 'Pago Único';

  @override
  String get noMoreAds => 'Sin más anuncios';

  @override
  String get lifetimeAccess => 'Acceso de por vida';

  @override
  String get purchaseNow => 'Comprar Ahora';

  @override
  String get limitedTimeOffer => 'Tiempo Limitado';

  @override
  String get discount25 => '25% Descuento';

  @override
  String get originalPrice => 'Precio Original';

  @override
  String get saveNow => 'Ahorra Ahora';

  @override
  String get bestValue => 'Mejor Valor';

  @override
  String get purchaseSuccessful =>
      '¡Compra exitosa! Ahora tienes acceso a las funciones premium.';

  @override
  String get lifetimeAccessMessage =>
      '¡Ahora tienes acceso de por vida a estos beneficios!';

  @override
  String get youArePremium => 'Eres Premium';

  @override
  String get active => 'ACTIVO';

  @override
  String get premiumAccessDescription =>
      '¡Tienes acceso a todas las funciones premium. Eliminación ilimitada, escaneo y más!';

  @override
  String get premiumActive => '¡Premium Activo!';

  @override
  String get premiumActiveMessage =>
      '¡Felicidades! Tu membresía premium está activa. Ahora tienes acceso a todas las funciones.';

  @override
  String get startUsing => 'Empezar a Usar';

  @override
  String get unlimited => 'Ilimitado';

  @override
  String get adFree => 'Sin anuncios';

  @override
  String get priority => 'Prioritario';

  @override
  String get paywallTitle => 'Desbloquea una galería más inteligente y limpia';

  @override
  String get paywallSubtitle =>
      'Limpieza con IA en el dispositivo. Pago único. Acceso de por vida.';

  @override
  String get oneTimeOffer => 'OFERTA ÚNICA';

  @override
  String get payOnceOwnForever => 'Paga una vez. Disfrútalo para siempre.';

  @override
  String get discount25Short => '25% DTO.';

  @override
  String get upgradeToPremium => 'Actualizar a Premium';

  @override
  String get continueWithFree => 'Continuar con la versión gratuita';

  @override
  String get noSubscriptionsNoFees => 'Sin suscripciones. Sin costes ocultos.';

  @override
  String get featureUnlimitedDeletions => 'Eliminaciones ilimitadas';

  @override
  String get featureUnlimitedDeletionsDesc => 'Limpia tu galería sin límites.';

  @override
  String get featureAIDetection => 'Detección de Blur y Duplicados con IA';

  @override
  String get featureAIDetectionDesc => 'Encuentra y elimina fotos no deseadas.';

  @override
  String get featureAutoClean => 'Sugerencias inteligentes de autolimpieza';

  @override
  String get featureAutoCleanDesc =>
      'Deja que la IA encuentre qué fotos borrar.';

  @override
  String get featureAdFree => 'Experiencia sin anuncios';

  @override
  String get featureAdFreeDesc =>
      'Disfruta de una interfaz fluida y sin anuncios.';

  @override
  String get processing => 'Procesando...';

  @override
  String get storeNotAvailable => 'La tienda no está disponible';

  @override
  String get purchaseFailed =>
      'La compra falló. Por favor, inténtalo de nuevo.';

  @override
  String get failedToInitiatePurchase => 'No se pudo iniciar la compra';

  @override
  String get purchaseError => 'Error de compra';

  @override
  String get purchasesRestoredSuccessfully =>
      '¡Compras restauradas exitosamente!';

  @override
  String get noPreviousPurchases =>
      'No se encontraron compras anteriores para restaurar.';

  @override
  String get restoreError => 'Error de restauración';

  @override
  String get restoring => 'Restaurando...';

  @override
  String get restorePurchases => 'Restaurar Compras';

  @override
  String get duplicatePhotos => 'Duplicate Photos';

  @override
  String get scanForDuplicates => 'Scan for Duplicates';

  @override
  String get scanningDuplicates => 'Scanning for duplicates...';

  @override
  String get noDuplicatesFound => 'No duplicate photos found';

  @override
  String duplicatesFound(int count) {
    return '$count duplicate groups found';
  }

  @override
  String get totalDuplicates => 'Total Duplicates';

  @override
  String get spaceToSave => 'Space to Save';

  @override
  String get deleteDuplicates => 'Delete Duplicates';

  @override
  String get selectAlbumsToScan => 'Select Albums to Scan';

  @override
  String get scanSelectedAlbums => 'Scan Selected Albums';

  @override
  String get deleteAllDuplicates => 'Eliminar Todos los Duplicados';

  @override
  String deleteAllDuplicatesMessage(int count) {
    return 'Se eliminarán $count fotos duplicadas. ¿Estás seguro?';
  }

  @override
  String get deleteAllBlurryPhotos => 'Eliminar Todas las Fotos Borrosas';

  @override
  String deleteAllBlurryPhotosMessage(int count) {
    return 'Se eliminarán $count fotos borrosas. ¿Estás seguro?';
  }

  @override
  String get startNewScan => 'Iniciar Nuevo Escaneo';

  @override
  String get scanResults => 'Resultados del Escaneo';

  @override
  String get scanCompleted => 'Escaneo Completado';

  @override
  String scanCompletedBlurMessage(int count) {
    return 'Se encontraron $count fotos borrosas';
  }

  @override
  String scanCompletedDuplicateMessage(int count) {
    return 'Se encontraron $count grupos duplicados';
  }

  @override
  String get noBlurryPhotosFound =>
      'No se encontraron fotos borrosas o pixeladas en su galería.';

  @override
  String get noDuplicatePhotosFound =>
      'No se encontraron fotos duplicadas en su galería.';

  @override
  String get duplicateGroup => 'Duplicate Group';

  @override
  String photosInGroup(int count) {
    return '$count photos';
  }

  @override
  String get keepOldest => 'Keep Oldest';

  @override
  String scanningAlbum(String album) {
    return 'Scanning $album...';
  }

  @override
  String get noDeleteRightsLeft => 'Sin Derechos de Eliminación';

  @override
  String get noDeleteRightsLeftMessage =>
      'No tienes derechos de eliminación. Obtén derechos de eliminación ilimitados para continuar limpiando tu galería.';

  @override
  String get galleryStatsTitle => 'Estadísticas de Galería';

  @override
  String get stop => 'Detener';

  @override
  String get spaceSaved => 'Espacio Ahorrado';

  @override
  String get lastAnalysis => 'Último análisis:';

  @override
  String get previousAnalysis => 'Análisis anterior:';

  @override
  String get mediaLabel => 'Medios';

  @override
  String get sizeLabel => 'Tamaño';

  @override
  String get albumDetails => 'Detalles del Álbum';

  @override
  String get mediaUnit => 'medios';

  @override
  String get ofGallery => 'de la galería';

  @override
  String get reAnalyze => 'Re-analizar';

  @override
  String get autoAnalyzeOnLaunch => 'Auto-analizar al abrir';

  @override
  String get autoAnalyzeOnLaunchDescription =>
      'Analizar galería automáticamente al abrir la aplicación';

  @override
  String progressFormat(String albums, int media) {
    return '$albums álbumes • $media medios';
  }

  @override
  String errorMessage(String error) {
    return 'Error: $error';
  }

  @override
  String get deleteOperationFailed =>
      'La operación de eliminación falló. Por favor, inténtalo de nuevo.';

  @override
  String get blurPhotosTitle => 'Fotos Borrosas';

  @override
  String get blurDetectionTitle => 'Detección de Desenfoque y Pixelación';

  @override
  String get blurPhotoDetection => 'Detección de Fotos Borrosas';

  @override
  String get blurDetectionDescription =>
      'Detecta fotos borrosas y pixeladas en los álbumes seleccionados';

  @override
  String get sensitivity => 'Sensibilidad';

  @override
  String get duplicateMode => 'Modo';

  @override
  String thresholdLabel(String value) {
    return 'Umbral: $value';
  }

  @override
  String get thresholdDescription =>
      'Valor bajo = Más detección de desenfoque\nValor alto = Solo fotos muy borrosas';

  @override
  String get sensitivityLow => 'Baja';

  @override
  String get sensitivityMedium => 'Media';

  @override
  String get sensitivityHigh => 'Alta';

  @override
  String get sensitivityDescription =>
      'El nivel de sensibilidad determina cuántas fotos borrosas se detectan. Baja sensibilidad detecta más fotos, alta sensibilidad solo encuentra fotos muy borrosas.';

  @override
  String get sensitivityLevelsDescription =>
      'Baja: Detecta fotos ligeramente borrosas también (más resultados)\nMedia: Detecta fotos moderadamente borrosas (equilibrado)\nAlta: Solo detecta fotos muy borrosas (menos resultados)';

  @override
  String get currentSensitivity => 'Sensibilidad Actual';

  @override
  String get noScanRightsLeft => 'Sin Derechos de Escaneo';

  @override
  String get albumSelection => 'Selección de Álbum';

  @override
  String get startScan => 'Iniciar Escaneo';

  @override
  String get scanningBlurPhotos => 'Escaneando fotos borrosas y pixeladas...';

  @override
  String get premiumScan => 'Escaneo Premium';

  @override
  String get remainingScanRights => 'Escaneo Restante';

  @override
  String get scanLimit => 'Límite de Escaneo';

  @override
  String get scanLimitLow =>
      '¡Tu límite de escaneo se está agotando! Actualiza a Premium.';

  @override
  String watchAdToGetScanLimit(int amount) {
    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'Ver Anuncio +$amountString Límite de Escaneo';
  }

  @override
  String get photoUnit => 'fotos';

  @override
  String get selectAlbumsAndScan => 'Selecciona álbumes y escanea';

  @override
  String get noDuplicateGroupsFound => 'No se encontraron grupos duplicados';

  @override
  String stateInfo(int albums, int groups) {
    return '$albums álbumes, $groups grupos';
  }

  @override
  String get blurDetectionDescriptionFromAppBar =>
      'Detección de fotos borrosas y pixeladas con inteligencia artificial. Limpia tu almacenamiento y mantén solo imágenes de calidad.';

  @override
  String get duplicateDetectionDescriptionFromAppBar =>
      'Detección de fotos duplicadas con inteligencia artificial. Limpia copias innecesarias y optimiza tu espacio de almacenamiento.';

  @override
  String get aiPowered => 'Con Inteligencia Artificial';

  @override
  String get listView => 'Vista de lista';

  @override
  String get gridView => 'Vista de cuadrícula';

  @override
  String get unknown => 'Desconocido';

  @override
  String blurScoreLabel(String score) {
    return 'Desenfoque: $score';
  }

  @override
  String pixelationScoreLabel(String score) {
    return 'Pixelación: $score';
  }

  @override
  String get deletePhoto => 'Eliminar Foto';

  @override
  String deletePhotoMessage(String type) {
    return 'Esta $type foto será eliminada.';
  }

  @override
  String get close => 'Cerrar';

  @override
  String deleteDuplicatesMessage(int count) {
    return '$count fotos duplicadas serán eliminadas.';
  }

  @override
  String get noResultsFound => 'No se encontraron resultados';

  @override
  String get group => 'Grupo';

  @override
  String get photo => 'Foto';

  @override
  String get blurry => 'Borrosa';

  @override
  String get pixelated => 'Pixelada';

  @override
  String get blurryAndPixelated => 'Borrosa y Pixelada';

  @override
  String get sharp => 'Nitida';

  @override
  String get scanningDuplicatePhotos => 'Escaneando fotos duplicadas...';

  @override
  String get duplicatePhotoDetection => 'Detección de Fotos Duplicadas';

  @override
  String get blurDetectionOnboardingTitle => 'Detectar Fotos Borrosas';

  @override
  String get blurDetectionOnboardingDescription =>
      'Detecta automáticamente fotos borrosas y pixeladas en tu galería. Puedes encontrar y eliminar estas fotos fácilmente.';

  @override
  String get duplicateDetectionOnboardingTitle => 'Encontrar Fotos Duplicadas';

  @override
  String get duplicateDetectionOnboardingDescription =>
      'Detecta fotos duplicadas en tu galería con algoritmo inteligente. Libera espacio limpiando copias innecesarias.';

  @override
  String get weNeedYourAccessTitle => 'Necesitamos Tu\nAcceso';

  @override
  String get resetToStart => 'Volver al Inicio';

  @override
  String get swipeTab => 'Deslizar';

  @override
  String get blurTab => 'Desenfoque';

  @override
  String get duplicateTab => 'Duplicado';

  @override
  String get cleanupComplete => '¡Limpieza Completada!';

  @override
  String get cleanupCompleteMessage =>
      'Todas las fotos seleccionadas han sido eliminadas exitosamente. Tu galería ahora está más limpia y ligera.';

  @override
  String cleanupCompleteMessageWithCount(int count) {
    return '$count foto(s) han sido eliminadas exitosamente. Tu galería ahora está más limpia y ligera.';
  }

  @override
  String get done => 'Hecho';

  @override
  String get viewGallery => 'Ver Galería';

  @override
  String get scanRightNotUsed => 'Tu derecho de escaneo no se utilizó';

  @override
  String get noBlurryPhotosFoundTitle => 'No se encontraron fotos borrosas';

  @override
  String get noDuplicatesFoundTitle => 'No se encontraron duplicados';

  @override
  String get scanCompletedSuccessfully =>
      '¡Buenas noticias! El escaneo de tu galería se completó exitosamente.';

  @override
  String get scanCompletedSuccessfullyDuplicate =>
      '¡Excelente! El escaneo de tu galería se completó exitosamente.';

  @override
  String get rateApp => 'Calificar App';

  @override
  String get rateAppDescription =>
      '¿Te gusta la app? ¡Por favor califícanos en la tienda!';

  @override
  String get couldNotOpenStore => 'No se pudo abrir la tienda';

  @override
  String estimatedTimeSeconds(int seconds) {
    return '~$seconds segundos';
  }

  @override
  String estimatedTimeMinutes(int minutes) {
    return '~$minutes minutos';
  }

  @override
  String estimatedScanTime(String time) {
    return 'Tiempo estimado: $time';
  }

  @override
  String maxPhotoLimitWarning(int count) {
    return 'El álbum seleccionado contiene $count fotos. Se pueden analizar un máximo de 1000 fotos a la vez.';
  }

  @override
  String get confirmBlurScan => '¿Iniciar detección de desenfoque?';

  @override
  String get confirmBlurScanMessage =>
      'Se realizará la detección de desenfoque en los álbumes seleccionados. ¿Desea continuar?';

  @override
  String get confirmDuplicateScan => '¿Iniciar detección de duplicados?';

  @override
  String get confirmDuplicateScanMessage =>
      'Se realizará la detección de duplicados en los álbumes seleccionados. ¿Desea continuar?';

  @override
  String get scan => 'Escanear';

  @override
  String get duplicateModeLowSpeedHighAccuracy =>
      'Baja Velocidad\nAlta Precisión';

  @override
  String get duplicateModeBalanced => 'Equilibrado';

  @override
  String get duplicateModeHighSpeedLowAccuracy =>
      'Alta Velocidad\nBaja Precisión';

  @override
  String get duplicateModeLevelsDescription =>
      'Baja Velocidad/Alta Precisión: Resultados más precisos, toma más tiempo\nEquilibrado: Equilibrio entre velocidad y precisión\nAlta Velocidad/Baja Precisión: Resultados rápidos, menos precisos';

  @override
  String get allPhotosReviewedTitle => '¡Todas las Fotos Revisadas!';

  @override
  String get allPhotosReviewedDescription =>
      '¡Buen trabajo! Has revisado todas las fotos disponibles.';

  @override
  String get removeAdsAndUnlimitedDeletions =>
      'Elimina Anuncios y Obtén Derechos Ilimitados';

  @override
  String get removeAdsAndUnlimitedDeletionsDescription =>
      '¡Actualiza a Premium y disfruta de una experiencia sin anuncios con derechos de eliminación ilimitados para siempre!';

  @override
  String get doNotLeaveScreenDuringScan =>
      'Por favor, no abandone esta pantalla mientras el escaneo está en progreso.';

  @override
  String get viewResults => 'Ver Resultados';

  @override
  String get viewLastResults => 'Ver Últimos Resultados';

  @override
  String get filterAndSort => 'Filtro y Orden';

  @override
  String get filterAndSortDescription => 'Opciones de rango de fechas y orden';

  @override
  String get dateRange => 'Rango de Fechas';

  @override
  String get startDate => 'Inicio';

  @override
  String get endDate => 'Fin';

  @override
  String get notSelected => 'No Seleccionado';

  @override
  String get clearDateFilter => 'Limpiar Filtro de Fecha';

  @override
  String get sort => 'Ordenar';

  @override
  String get newest => 'Más Recientes';

  @override
  String get oldest => 'Más Antiguos';

  @override
  String get apply => 'Aplicar';

  @override
  String get albumSettings => 'Configuración de Álbum';

  @override
  String get getUnlimitedScans => 'Obtener Escaneos Ilimitados';

  @override
  String get noRightsLeft => 'No quedan derechos';

  @override
  String get getUnlimitedDeletions => 'Obtener Eliminaciones Ilimitadas';

  @override
  String get scanTip1 =>
      'Mientras escaneamos tus fotos, puedes desplazarte por los reels.';

  @override
  String get scanTip2 =>
      'Mientras escaneamos, puedes leer media página de un libro.';

  @override
  String get scanTip3 =>
      'Mientras escaneamos, puedes responder al mensaje de tu pareja.';

  @override
  String get scanTip4 =>
      'Mientras escaneamos, puedes revisar tus notificaciones.';

  @override
  String get scanTip5 => 'Mientras escaneamos, puedes tomar un breve descanso.';

  @override
  String get scanTip6 =>
      'Puedes minimizar la app al fondo, pero no la cierres completamente.';

  @override
  String get scanTip7 =>
      'Mientras escaneamos, puedes navegar por otras apps sin cerrar esta.';

  @override
  String get scanTip8 =>
      'Mientras escaneamos, puedes hacer una llamada rápida.';

  @override
  String get scanTip9 =>
      'Mientras escaneamos, puedes revisar tus redes sociales.';

  @override
  String get scanTip10 => 'Mientras escaneamos, puedes tomar una taza de café.';
}

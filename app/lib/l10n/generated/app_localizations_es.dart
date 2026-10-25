// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'WuselWall';

  @override
  String get unexpectedError => 'Se ha producido un error inesperado';

  @override
  String get retry => 'Volver a intentar';

  @override
  String get errorNetwork =>
      'No hay conexión con el servidor. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get errorAuth => 'No has iniciado sesión o tu sesión ha caducado.';

  @override
  String get errorPermission => 'No tienes permiso para hacer eso.';

  @override
  String get errorNotFound => 'No se ha encontrado lo que buscabas.';

  @override
  String get errorConflict => 'Esto entra en conflicto con algo que ya existe.';

  @override
  String get errorValidation => 'Los datos introducidos no son válidos.';

  @override
  String get errorUnknown => 'Algo ha salido mal.';

  @override
  String configMissing(String missing) {
    return 'A esta compilación le falta la configuración: $missing';
  }

  @override
  String get registerAdult => 'Adulto';

  @override
  String get registerKid => 'Infantil';

  @override
  String get registerKiosk => 'Pantalla de pared';

  @override
  String get systemTitle => 'Sistema';

  @override
  String get systemBuild => 'Compilación';

  @override
  String get systemEnvironment => 'Entorno';

  @override
  String get systemBackendUrl => 'URL del servidor';

  @override
  String get systemConnectivity => 'Conectividad';

  @override
  String get systemNetwork => 'Red';

  @override
  String get systemOnline => 'Con conexión';

  @override
  String get systemOffline => 'Sin conexión';

  @override
  String get systemUnknown => 'Desconocido';

  @override
  String get systemBackend => 'Servidor';

  @override
  String get systemStatus => 'Estado';

  @override
  String get systemStatusOk => 'OK';

  @override
  String get systemDbVersion => 'Versión de la base de datos';

  @override
  String get systemServerTime => 'Hora del servidor';

  @override
  String get setupHeadline => 'Te damos la bienvenida a WuselWall';

  @override
  String get setupOfflineWelcome =>
      'No tienes conexión. Conéctate a Internet para iniciar sesión, aceptar una invitación o conectar un dispositivo compartido. Estas opciones estarán disponibles cuando vuelvas a conectarte.';

  @override
  String get doorTagline => 'El plan familiar para la pared de la cocina';

  @override
  String get setupHouseholdAction => 'Crear una familia nueva';

  @override
  String get wizardTitle => 'Nuevo hogar';

  @override
  String get wizardCreate => 'Crear hogar';

  @override
  String get fieldSetupToken => 'Código de configuración';

  @override
  String get fieldHouseholdName => 'Nombre del hogar';

  @override
  String get fieldYourName => 'Tu nombre';

  @override
  String get fieldEmail => 'Correo electrónico';

  @override
  String get fieldPassword => 'Contraseña (al menos 10 caracteres)';

  @override
  String get fieldPasswordSimple => 'Contraseña';

  @override
  String get fieldPin => 'PIN de 6 dígitos';

  @override
  String get fieldRequired => 'Obligatorio';

  @override
  String get signInTitle => 'Iniciar sesión';

  @override
  String get signInAction => 'Iniciar sesión';

  @override
  String get enrolTitle => 'Conectar este dispositivo';

  @override
  String get enrolBody =>
      'Introduce el código que aparece en un dispositivo que ya esté conectado.';

  @override
  String get enrolCodeLabel => 'Código de vinculación';

  @override
  String get enrolAction => 'Conectar';

  @override
  String get errSetupTokenInvalid => 'El código de configuración no es válido.';

  @override
  String get errSetupClosed => 'Este sistema ya está conectado.';

  @override
  String get errPasswordTooShort =>
      'La contraseña debe tener al menos 10 caracteres.';

  @override
  String get errPinFormat => 'El PIN debe tener exactamente 6 dígitos.';

  @override
  String get errCodeInvalid => 'El código es incorrecto o ha caducado.';

  @override
  String get errGuardianRequired =>
      'Solo una persona responsable puede hacer eso.';

  @override
  String get errDeviceRevoked => 'Este dispositivo está bloqueado.';

  @override
  String get errActorRequired => 'Primero toca tu nombre.';

  @override
  String get errNameRequired => 'Introduce un nombre.';

  @override
  String get errInvalidLogin => 'El correo o la contraseña son incorrectos.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get close => 'Cerrar';

  @override
  String get delete => 'Eliminar';

  @override
  String get yes => 'Sí';

  @override
  String get no => 'No';

  @override
  String get shoppingTitle => 'Lista de la compra';

  @override
  String get shoppingAddHint => 'Añadir producto';

  @override
  String get shoppingQuantityHint => 'Cantidad';

  @override
  String get shoppingEmpty => 'No hay nada que comprar';

  @override
  String get shoppingFinish => 'Terminar la compra';

  @override
  String get shoppingFinishConfirm =>
      '¿Terminar esta compra? Se eliminarán los productos marcados y el resto seguirá en la lista.';

  @override
  String shoppingFinished(int bought, int left) {
    return '$bought comprados, $left pendientes';
  }

  @override
  String get actingWho => '¿Quién eres?';

  @override
  String get pinTitle => 'PIN de responsable';

  @override
  String pinPrompt(String name) {
    return 'Introduce el PIN de $name';
  }

  @override
  String pinWrong(int left) {
    return 'PIN incorrecto. Quedan $left intentos.';
  }

  @override
  String get pinBackoff => 'Demasiados intentos. Espera un momento.';

  @override
  String get pinLocked =>
      'PIN bloqueado. Una persona responsable debe iniciar sesión para desbloquearlo.';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsMembers => 'Miembros';

  @override
  String get settingsDevices => 'Dispositivos';

  @override
  String get addMember => 'Añadir miembro';

  @override
  String get memberName => 'Nombre';

  @override
  String get roleGuardian => 'Responsable';

  @override
  String get roleMember => 'Miembro';

  @override
  String get addDevice => 'Añadir dispositivo';

  @override
  String get deviceLabel => 'Nombre del dispositivo';

  @override
  String get createCode => 'Crear código';

  @override
  String get enrolmentCodeTitle => 'Código de vinculación';

  @override
  String get enrolmentCodeHint =>
      'Introduce este código en el nuevo dispositivo en un plazo de 10 minutos. Solo se puede usar una vez.';

  @override
  String get thisDevice => 'este dispositivo';

  @override
  String get deviceRevoked => 'bloqueado';

  @override
  String get revoke => 'Bloquear';

  @override
  String revokeConfirm(String device) {
    return '¿Bloquear «$device»? Perderá el acceso de inmediato.';
  }

  @override
  String get signOutDevice => 'Cerrar sesión en este dispositivo';

  @override
  String get classPersonal => 'Personal';

  @override
  String get classShared => 'Compartido';

  @override
  String get classSharedHint =>
      'Lo usan varias personas: toca un nombre para cambiar.';

  @override
  String get classKiosk => 'Pantalla de pared';

  @override
  String get systemDevice => 'Este dispositivo';

  @override
  String get systemRegister => 'Vista';

  @override
  String get systemEnrolled => 'Vinculado';

  @override
  String get errRateLimited =>
      'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';

  @override
  String get errMfaRequired =>
      'Primero introduce el código de tu aplicación de autenticación.';

  @override
  String get scanQr => 'Escanear código QR';

  @override
  String get scanTitle => 'Escanear el código de configuración';

  @override
  String get enrolmentQrLabel => 'Código QR de vinculación';

  @override
  String get mfaTitle => 'Segundo factor';

  @override
  String get mfaBody =>
      'Introduce el código de 6 dígitos de tu aplicación de autenticación.';

  @override
  String get mfaCodeLabel => 'Código de 6 dígitos';

  @override
  String get mfaVerify => 'Confirmar';

  @override
  String get registerTitle => 'Pon un nombre a este dispositivo';

  @override
  String registerBody(String name) {
    return '$name, este teléfono es nuevo en el hogar. Ponle un nombre para poder reconocerlo y bloquearlo más adelante.';
  }

  @override
  String registerDefaultLabel(String name) {
    return 'Teléfono de $name';
  }

  @override
  String get registerAction => 'Usar este dispositivo';

  @override
  String get signInPasskey => 'Iniciar sesión con clave de acceso';

  @override
  String get settingsSecurity => 'Seguridad';

  @override
  String get totpTitle => 'Inicio de sesión en dos pasos';

  @override
  String get totpOn => 'Activado: se pide un código al iniciar sesión.';

  @override
  String get totpOff => 'Desactivado';

  @override
  String get totpEnable => 'Activar';

  @override
  String get totpDisable => 'Desactivar';

  @override
  String get totpScanBody =>
      'Escanea este código con una aplicación de autenticación e introduce el código de 6 dígitos que aparezca.';

  @override
  String get totpQrLabel =>
      'Código QR para configurar la aplicación de autenticación';

  @override
  String get passkeyTitle => 'Clave de acceso';

  @override
  String get passkeyBody =>
      'Inicia sesión con tu huella o tu rostro en lugar de una contraseña.';

  @override
  String get passkeyAdd => 'Añadir';

  @override
  String get passkeyAdded => 'Clave de acceso añadida.';

  @override
  String get shoppingHistory => 'Historial';

  @override
  String get shoppingHistoryEmpty => 'Aún no hay compras terminadas';

  @override
  String get shoppingSearchHint => 'Buscar o añadir';

  @override
  String get shoppingTilesEmpty =>
      'Aquí aparecerán tarjetas cuando hayáis comprado algo. Escribe un nombre para añadir un producto.';

  @override
  String shoppingInTrolley(int count) {
    return 'En el carrito ($count)';
  }

  @override
  String get shoppingUncategorised => 'Sin categoría';

  @override
  String get shoppingNewList => 'Nueva lista';

  @override
  String get shoppingListName => 'Nombre';

  @override
  String get shoppingListKind => 'Distribución';

  @override
  String get shoppingKindSupermarket => 'Supermercado';

  @override
  String get shoppingKindDrugstore => 'Droguería';

  @override
  String get shoppingKindHardware => 'Ferretería';

  @override
  String get shoppingKindOther => 'Otros';

  @override
  String get shoppingMakeDefault => 'Usar como lista predeterminada';

  @override
  String get shoppingEditItem => 'Editar producto';

  @override
  String get shoppingSpecHint => 'Nota, p. ej., ecológico o 500 g';

  @override
  String get shoppingCategory => 'Categoría';

  @override
  String get shoppingRemoveOne => 'Uno menos';

  @override
  String get errListExists => 'Ya existe una lista con ese nombre.';

  @override
  String get errSpecTooLong =>
      'La nota es demasiado larga (máximo 40 caracteres).';

  @override
  String get errKioskForbidden =>
      'Esto no se puede hacer en la pantalla de pared.';

  @override
  String get shoppingCat_produce => 'Frutas y verduras';

  @override
  String get shoppingCat_bakery => 'Pan y bollería';

  @override
  String get shoppingCat_dairy => 'Lácteos y quesos';

  @override
  String get shoppingCat_meat_fish => 'Carne y pescado';

  @override
  String get shoppingCat_pantry => 'Despensa';

  @override
  String get shoppingCat_frozen => 'Congelados';

  @override
  String get shoppingCat_drinks => 'Bebidas';

  @override
  String get shoppingCat_household => 'Hogar';

  @override
  String get shoppingCat_other => 'Otros';

  @override
  String get shoppingCat_care => 'Cuidado personal';

  @override
  String get shoppingCat_baby => 'Bebés y niños';

  @override
  String get shoppingCat_cleaning => 'Limpieza';

  @override
  String get shoppingCat_health => 'Salud';

  @override
  String get shoppingCat_tools => 'Herramientas';

  @override
  String get shoppingCat_screws => 'Tornillos y fijaciones';

  @override
  String get shoppingCat_electrical => 'Electricidad';

  @override
  String get shoppingCat_garden => 'Jardín';

  @override
  String shoppingCreateTile(String name) {
    return 'Añadir «$name»';
  }

  @override
  String shoppingAddedBy(String name) {
    return 'Añadido por $name';
  }

  @override
  String get pinChangeTitle => 'PIN de responsable';

  @override
  String get pinChangeBody =>
      'Establece un nuevo PIN de 6 dígitos. Esto también desbloquea un PIN bloqueado por demasiados intentos fallidos.';

  @override
  String get pinChangeAction => 'Cambiar';

  @override
  String get pinChangeField => 'Nuevo PIN (6 dígitos)';

  @override
  String get pinChanged => 'PIN cambiado.';

  @override
  String shoppingTripItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count productos',
      one: '1 producto',
    );
    return '$_temp0';
  }

  @override
  String shoppingPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cambios pendientes de envío',
      one: '1 cambio pendiente de envío',
    );
    return '$_temp0';
  }

  @override
  String get shoppingItemPending => 'Pendiente de envío';

  @override
  String get errCategoryNotFound =>
      'Esta categoría ya no existe. No se ha guardado el cambio.';

  @override
  String get errNameTooLong => 'El nombre es demasiado largo.';

  @override
  String get errActorInvalid =>
      'Esta persona ya no forma parte del hogar. No se ha guardado el cambio.';

  @override
  String get doorEmail => 'Continuar con correo electrónico';

  @override
  String get doorOr => 'o';

  @override
  String get errSignupDisabled =>
      'Aún no hay una cuenta de WuselWall para esta dirección. Pide una invitación a tu familia o crea una familia nueva.';

  @override
  String get errEmailExists =>
      'Esta dirección de correo ya pertenece a otra cuenta.';

  @override
  String get signInMethodsTitle => 'Inicio de sesión';

  @override
  String get signInMethodEmail => 'Código por correo';

  @override
  String boardWeekNumber(int week) {
    return 'Semana $week';
  }

  @override
  String get boardToday => 'Hoy';

  @override
  String get boardNow => 'Ahora';

  @override
  String get boardNextUp => 'A continuación';

  @override
  String get boardThen => 'después';

  @override
  String boardInMinutes(int minutes) {
    return 'en $minutes min';
  }

  @override
  String boardInHours(int hours, int minutes) {
    return 'en $hours h $minutes min';
  }

  @override
  String get boardNothingMoreToday => 'No hay nada más previsto para hoy';

  @override
  String boardLastUpdatedAt(String time) {
    return 'última actualización: $time';
  }

  @override
  String get boardOffline => 'Sin conexión: este es el último plan disponible.';

  @override
  String get boardLoading => 'Cargando la semana…';

  @override
  String get boardZoneWhere => 'Quién está dónde';

  @override
  String get boardZoneMeal => 'Comida caliente';

  @override
  String get boardMorning => 'Mañana';

  @override
  String get boardAfternoon => 'Tarde';

  @override
  String get boardEvening => 'Noche';

  @override
  String boardUntil(String time) {
    return 'hasta las $time';
  }

  @override
  String boardFrom(String time) {
    return 'desde las $time';
  }

  @override
  String get boardAllDay => 'todo el día';

  @override
  String boardMoreEvents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count más',
      one: '+1 más',
    );
    return '$_temp0';
  }

  @override
  String boardMoreCount(int count) {
    return '+$count';
  }

  @override
  String get boardNoSchool => 'libre';

  @override
  String boardCareUntil(String label, String time) {
    return '$label hasta las $time';
  }

  @override
  String get boardCareDefault => 'Cuidado infantil';

  @override
  String boardBusyUntil(String time) {
    return 'Reuniones hasta las $time';
  }

  @override
  String get boardMealLunch => 'Almuerzo';

  @override
  String get boardMealDinner => 'Cena';

  @override
  String get boardMealNothingPlanned => 'nada previsto';

  @override
  String boardMealCook(String name) {
    return '$name cocina';
  }

  @override
  String boardMealGuests(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count invitados',
      one: '+1 invitado',
    );
    return '$_temp0';
  }

  @override
  String boardEating(String name) {
    return '$name come en casa';
  }

  @override
  String boardNotEating(String name) {
    return '$name no come en casa';
  }

  @override
  String get boardOpenToday => 'Pendiente para hoy';

  @override
  String get boardAllDone => 'Todo hecho por hoy';

  @override
  String get boardShoppingList => 'Lista de la compra';

  @override
  String get boardNightMode => 'Vista nocturna';

  @override
  String get boardBackToWeek => 'Volver a la semana';

  @override
  String get boardTentative => 'aún sin confirmar';

  @override
  String get boardNoAppointments => 'Sin citas';

  @override
  String get boardSchool => 'Colegio';

  @override
  String boardSchoolSpan(String span) {
    return 'Colegio $span';
  }

  @override
  String get boardNoSchoolToday => 'Sin colegio';

  @override
  String get boardWeekend => 'Fin de semana';

  @override
  String boardWeekOf(String name) {
    return 'La semana de $name';
  }

  @override
  String boardTimetableTitle(String name) {
    return 'Horario de $name';
  }

  @override
  String boardClass(String label) {
    return 'Clase $label';
  }

  @override
  String boardPeriod(int index) {
    return 'Clase $index';
  }

  @override
  String get boardBreak => 'Recreo';

  @override
  String get boardLessonOver => 'terminada';

  @override
  String get boardLessonNow => 'ahora';

  @override
  String get boardLessonCancelled => 'Cancelada';

  @override
  String get boardLessonSubstituted => 'Suplencia';

  @override
  String get boardLessonRoomChange => 'Cambio de aula';

  @override
  String get boardLessonExtra => 'Extra';

  @override
  String boardPackTomorrow(String items) {
    return 'Preparar para mañana: $items';
  }

  @override
  String boardPackToday(String items) {
    return 'Llevar hoy: $items';
  }

  @override
  String get boardWholeWeek => 'Toda la semana';

  @override
  String get boardMealWeek => 'Las comidas de esta semana';

  @override
  String boardBaseline(String label) {
    return 'Normalmente: $label';
  }

  @override
  String get boardNoDeviation => 'como siempre';

  @override
  String get boardCooking => 'Cocina';

  @override
  String get boardAppointmentsOf => 'Citas';

  @override
  String boardTasksOf(String name) {
    return 'Tareas de $name';
  }

  @override
  String get boardTasksComingSoon =>
      'Las tareas llegarán con la próxima actualización.';

  @override
  String get presenceWorking => 'En el trabajo';

  @override
  String get presenceHomeOffice => 'Teletrabajo';

  @override
  String get presenceTravel => 'De viaje';

  @override
  String get presenceAway => 'Fuera';

  @override
  String get presenceOff => 'Día libre';

  @override
  String get presenceChildcare => 'Cuidado infantil';

  @override
  String get errSettingInvalid =>
      'Este valor está fuera del intervalo permitido.';

  @override
  String get errSettingUnknown => 'Este ajuste no existe.';

  @override
  String get errSettingTarget =>
      'Este ajuste no se puede cambiar para esta persona o dispositivo.';

  @override
  String get settingPickPersonFirst =>
      'Primero elige quién eres. Después aparecerán aquí tus ajustes.';

  @override
  String get settingIsDefault => 'Predeterminado';

  @override
  String get settingIsCustom => 'Personalizado';

  @override
  String get settingReset => 'Restablecer valor predeterminado';

  @override
  String get settingOn => 'Activado';

  @override
  String get settingOff => 'Desactivado';

  @override
  String get settingFrom => 'desde';

  @override
  String get settingTo => 'hasta';

  @override
  String get settingIncrease => 'Aumentar';

  @override
  String get settingDecrease => 'Reducir';

  @override
  String get settingDayPartsMorningEnds => 'Mañana hasta';

  @override
  String get settingDayPartsEveningStarts => 'Noche desde';

  @override
  String settingUnitPoints(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count puntos',
      one: '1 punto',
    );
    return '$_temp0';
  }

  @override
  String settingUnitMinutes(int count) {
    return '$count min';
  }

  @override
  String settingUnitSeconds(int count) {
    return '$count s';
  }

  @override
  String get settingValueName => 'Nombre completo';

  @override
  String get settingValueInitial => 'Inicial';

  @override
  String get settingValueDuty => 'Obligatoria';

  @override
  String get settingValueBonus => 'Extra';

  @override
  String get settingValueRequired => 'Con aprobación';

  @override
  String get settingValueSelfServe => 'Canje directo';

  @override
  String get settingValueWholeFamily => 'Toda la familia';

  @override
  String get settingValueAll => 'Todos';

  @override
  String get settingValueNone => 'Ninguno';

  @override
  String get settingValueLunch => 'Almuerzo';

  @override
  String get settingValueDinner => 'Cena';

  @override
  String get settingBoardMemberLabelTitle => 'Nombres en el panel';

  @override
  String get settingBoardMemberLabelHelp =>
      'A dos metros se lee mejor un nombre que una inicial. Elige iniciales si suele haber visitas en la cocina.';

  @override
  String get settingTasksDutyPointsTitle => 'Puntos por tarea obligatoria';

  @override
  String get settingTasksDutyPointsHelp =>
      'Las tareas obligatorias corresponden a todos, así que dan pocos puntos o ninguno. Su recompensa es mantener la racha.';

  @override
  String get settingTasksBonusPointsTitle => 'Puntos por tarea extra';

  @override
  String get settingTasksBonusPointsHelp =>
      'Una tarea extra basta para conseguir la recompensa inicial más barata, para que los más pequeños la alcancen en pocos días.';

  @override
  String get settingTasksKindTitle => 'Las nuevas tareas son';

  @override
  String get settingTasksKindHelp =>
      'Una nueva tarea es obligatoria salvo que alguien la convierta expresamente en extra. Así se limita qué tareas dan puntos.';

  @override
  String get settingTasksVerificationTitle =>
      'Los responsables revisan las tareas';

  @override
  String get settingTasksVerificationHelp =>
      'La revisión convierte cada tarea en una inspección. Úsala solo para tareas extra de mucho valor.';

  @override
  String get settingTasksJokersTitle => 'Comodines de racha al mes';

  @override
  String get settingTasksJokersHelp =>
      'Un comodín mantiene la racha si se pierde un día. Así, un día de enfermedad no borra una racha de tres semanas.';

  @override
  String get settingTasksRewardApprovalTitle =>
      'Las recompensas necesitan aprobación';

  @override
  String get settingTasksRewardApprovalHelp =>
      'Una persona responsable aprueba cada canje con su PIN. El canje directo solo es adecuado para pequeñas recompensas.';

  @override
  String get settingCalendarMembersEditTitle =>
      'Los miembros editan sus propios eventos';

  @override
  String get settingCalendarMembersEditHelp =>
      'Los niños pueden crear y editar los eventos en los que participan. Solo los responsables pueden eliminar eventos de otras personas.';

  @override
  String get settingCalendarKeyDefaultTitle =>
      'Nuevos eventos en la pantalla de la cocina';

  @override
  String get settingCalendarKeyDefaultHelp =>
      'Decide qué eventos nuevos aparecen en la pantalla de la cocina sin marcar ninguna casilla. Revísalo tras dos semanas de uso.';

  @override
  String get settingSchoolReportTitle =>
      'Los miembros avisan de cambios de horario';

  @override
  String get settingSchoolReportHelp =>
      'Solo los responsables mantienen el horario. Con esta opción, un niño puede avisar de una clase cancelada para que un responsable lo confirme.';

  @override
  String get settingSchoolEquipmentTitle => 'Material para mañana';

  @override
  String get settingSchoolEquipmentHelp =>
      'Muestra qué hay que llevar mañana según las asignaturas, como la ropa de deporte.';

  @override
  String get settingMealsSchoolDayTitle => 'Comida caliente en días lectivos';

  @override
  String get settingMealsSchoolDayHelp =>
      'La comida caliente que aparece en la pantalla de la cocina. En días lectivos, los niños almuerzan en el colegio o en el servicio de cuidado extraescolar.';

  @override
  String get settingMealsFreeDayTitle => 'Comida caliente en días libres';

  @override
  String get settingMealsFreeDayHelp => 'Para fines de semana y vacaciones.';

  @override
  String get settingMealsAwayTitle => 'Estar fuera significa no comer en casa';

  @override
  String get settingMealsAwayHelp =>
      'Quien esté de viaje o fuera a la hora de comer se marca como ausente de esa comida. Así no hay que introducir nada la mayoría de los días.';

  @override
  String get settingMealsCareCutoffTitle =>
      'Hora límite del cuidado para el almuerzo';

  @override
  String get settingMealsCareCutoffHelp =>
      'Si el cuidado infantil termina después de esta hora, se considera que el niño almuerza fuera.';

  @override
  String get settingBoardRolloverTitle => 'El panel pasa a la próxima semana';

  @override
  String get settingBoardRolloverHelp =>
      'Cuándo la pantalla pasa a la semana siguiente. El domingo por la noche interesa planificar la próxima semana; el sábado por la mañana, aún la actual.';

  @override
  String get settingBoardDayPartsTitle => 'Mañana, tarde y noche';

  @override
  String get settingBoardDayPartsHelp =>
      'Cuándo se divide la zona de citas entre mañana, tarde y noche.';

  @override
  String get settingDeviceNightHoursTitle => 'Horario del tema nocturno';

  @override
  String get settingDeviceNightHoursHelp =>
      'Cuándo la pantalla de pared cambia al tema nocturno de color ámbar.';

  @override
  String get settingDeviceIdleRevertTitle => 'Volver al panel después de';

  @override
  String get settingDeviceIdleRevertHelp =>
      'Cuánto tiempo permanece abierto un perfil o una vista de detalle antes de volver al panel de pared.';

  @override
  String get settingMemberCompletionSoundTitle =>
      'Sonido al completar una tarea';

  @override
  String get settingMemberCompletionSoundHelp =>
      'Al marcar una tarea como hecha suena un sonido breve. Desactívalo si no lo quieres.';

  @override
  String get settingCalendarTentativeTitle =>
      'Revisar eventos sin confirmar a las';

  @override
  String get settingCalendarTentativeHelp =>
      'Pregunta si un evento provisional se va a celebrar para que no siga sin confirmar hasta que empiece.';

  @override
  String get settingNotifyMorningTitle => 'Resumen de la mañana';

  @override
  String get settingNotifyMorningHelp =>
      'Tus tareas y eventos de hoy. Los responsables también ven los canjes pendientes.';

  @override
  String get settingNotifyEventReminderTitle =>
      'Recordatorio antes de los eventos';

  @override
  String get settingNotifyEventReminderHelp =>
      'Una notificación antes de que empiece un evento.';

  @override
  String get settingNotifyTaskVerifiedTitle => 'Cuando se confirma una tarea';

  @override
  String get settingNotifyTaskVerifiedHelp =>
      'Una notificación cuando un responsable confirma una tarea y se suman sus puntos.';

  @override
  String get settingNotifyRedemptionTitle => 'Cuando se pide una recompensa';

  @override
  String get settingNotifyRedemptionHelp =>
      'Una notificación inmediata cuando un niño pide una recompensa.';

  @override
  String boardCareShort(String label, String time) {
    return '$label $time';
  }

  @override
  String get calendarTitle => 'Calendario';

  @override
  String get calendarDay => 'Día';

  @override
  String get calendarThreeDays => '3 días';

  @override
  String get calendarWeek => 'Semana';

  @override
  String get calendarPrevious => 'Anterior';

  @override
  String get calendarNext => 'Siguiente';

  @override
  String get calendarChooseView => 'Vista del calendario';

  @override
  String get calendarToday => 'Hoy';

  @override
  String calendarRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get calendarNewEvent => 'Nuevo evento';

  @override
  String get calendarEmpty => 'Nada previsto';

  @override
  String get calendarEditorPlaceholder =>
      'El editor de eventos estará disponible pronto.';

  @override
  String get eventEditTitle => 'Editar evento';

  @override
  String get eventTitleLabel => 'Título';

  @override
  String get eventTitleRequired => 'Introduce un título.';

  @override
  String get eventKindAppointment => 'Cita';

  @override
  String get eventKindPresence => 'Presencia';

  @override
  String get eventPresenceState => 'Estado';

  @override
  String get eventPresenceStateRequired => 'Elige un estado.';

  @override
  String get eventAllDay => 'Todo el día';

  @override
  String get eventStarts => 'Inicio';

  @override
  String get eventEnds => 'Fin';

  @override
  String get eventEndBeforeStart => 'El final debe ser posterior al inicio.';

  @override
  String get eventAttendees => 'Quién';

  @override
  String get eventAttendeesWholeFamily =>
      'Sin personas seleccionadas: el evento es para toda la familia.';

  @override
  String get eventLocation => 'Lugar';

  @override
  String get eventNotes => 'Notas';

  @override
  String get eventTentative => 'Aún sin confirmar';

  @override
  String get eventKeyDisplay => 'Mostrar en la pantalla de la cocina';

  @override
  String get eventKeyDisplayOn =>
      'Este evento aparece en la pantalla de la cocina.';

  @override
  String get eventKeyDisplayOff =>
      'Este evento no aparece en la pantalla de la cocina.';

  @override
  String get eventKeyDisplayOffWholeFamily =>
      'No aparece en la pantalla de la cocina: por defecto solo aparecen allí los eventos de toda la familia.';

  @override
  String get eventRepeat => 'Repetir';

  @override
  String get eventRepeatNever => 'Nunca';

  @override
  String get eventRepeatDaily => 'Cada día';

  @override
  String get eventRepeatWeekly => 'Cada semana';

  @override
  String get eventRepeatBiweekly => 'Cada 2 semanas';

  @override
  String get eventRepeatMonthly => 'Cada mes';

  @override
  String get eventRepeatSpecificDays => 'Días concretos (turnos de trabajo)';

  @override
  String eventRepeatMonthlyDay(int day) {
    return 'el día $day';
  }

  @override
  String eventRepeatMonthlyNth(int n, String weekday) {
    return 'el $n.º $weekday del mes';
  }

  @override
  String eventRepeatMonthlyLast(String weekday) {
    return 'el último $weekday';
  }

  @override
  String get eventRepeatDays => 'Estos días';

  @override
  String get eventRepeatEnds => 'Fin de la repetición';

  @override
  String get eventRepeatUntil => 'en una fecha';

  @override
  String eventRepeatCount(int count) {
    return 'después de $count veces';
  }

  @override
  String eventDaysPicked(int count) {
    return '$count días';
  }

  @override
  String get eventDienstplanHelp =>
      'Toca los días que correspondan. El día de inicio siempre se incluye.';

  @override
  String get eventCustomRule => 'Regla personalizada';

  @override
  String get eventCustomRuleHelp =>
      'Esta pauta de repetición no se puede editar aquí. Se conservará tal cual.';

  @override
  String get eventWeekdaysRequired => 'Elige al menos un día de la semana.';

  @override
  String get eventDeleteConfirm => '¿Eliminar este evento?';

  @override
  String get eventScopeTitle => '¿Qué eventos?';

  @override
  String get eventScopeDeleteTitle => '¿Qué eventos quieres eliminar?';

  @override
  String get eventScopeThis => 'Solo este evento';

  @override
  String get eventScopeSeries => 'Todos los eventos de la serie';

  @override
  String get errEventInvalid => 'Este evento no es válido.';

  @override
  String get errRruleInvalid => 'No se puede guardar esta pauta de repetición.';

  @override
  String get errAttendeeInvalid =>
      'Una de las personas elegidas no pertenece a este hogar.';

  @override
  String get errEventNotFound => 'Este evento ya no existe.';

  @override
  String get scheduleTitle => 'Horario escolar';

  @override
  String get tasksTitle => 'Tareas';

  @override
  String get mealsTitle => 'Comidas';

  @override
  String get comingSoon => 'Estamos preparando esta sección.';

  @override
  String mealsWeekRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get mealsPrevWeek => 'Semana anterior';

  @override
  String get mealsNextWeek => 'Semana siguiente';

  @override
  String get mealsThisWeek => 'Esta semana';

  @override
  String get mealsRecipes => 'Recetas';

  @override
  String get mealsFillShopping => 'Completar la lista de la compra';

  @override
  String get mealsSlotBreakfast => 'Desayuno';

  @override
  String get mealsSlotLunch => 'Almuerzo';

  @override
  String get mealsSlotDinner => 'Cena';

  @override
  String get mealsSlotSnack => 'Tentempié';

  @override
  String get mealsNothingYet => 'Aún no hay nada previsto';

  @override
  String get mealsAddOther => 'Añadir comida';

  @override
  String get mealsDragHint =>
      'Mantén pulsada una comida y arrástrala a otro día para moverla.';

  @override
  String mealsEditTitle(String day) {
    return 'Comida del $day';
  }

  @override
  String get mealsFieldLabel => 'Plato o nota';

  @override
  String get mealsFieldHint => 'Pizza, sobras, el nombre de una receta…';

  @override
  String get mealsSuggestionHelp =>
      'Recetas que coinciden. Toca una para usarla; sus ingredientes se añadirán a la lista de la compra.';

  @override
  String get mealsServings => 'Raciones';

  @override
  String get mealsCook => 'Quién cocina';

  @override
  String get mealsCookNobody => 'Nadie';

  @override
  String get mealsTime => 'Hora';

  @override
  String get mealsTimeNone => 'Sin hora';

  @override
  String get mealsGuests => 'Invitados';

  @override
  String get mealsEatingTitle => 'Quién come en casa';

  @override
  String get mealsEatingHelp =>
      'Quien esté fuera o de viaje a la hora de comer, o se quede en el cuidado extraescolar después de la hora límite, se excluye automáticamente. Cámbialo a mano solo si no es así.';

  @override
  String get mealsEatingAuto => 'Automático';

  @override
  String get mealsEatingYes => 'Come en casa';

  @override
  String get mealsEatingNo => 'No come en casa';

  @override
  String get mealsDelete => 'Eliminar comida';

  @override
  String get mealsPreviewTitle => 'Completar la lista de la compra';

  @override
  String get mealsPreviewEmpty =>
      'No hay nada que añadir. Las comidas escritas a mano no tienen ingredientes; las recetas sí los añaden a la lista.';

  @override
  String get mealsPreviewOnList => 'Ya está en la lista';

  @override
  String mealsPreviewFor(String meals) {
    return 'Para $meals';
  }

  @override
  String mealsPreviewAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Añadir $count productos',
      one: 'Añadir 1 producto',
      zero: 'No añadir nada',
    );
    return '$_temp0';
  }

  @override
  String mealsPreviewAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count productos añadidos a la lista de la compra',
      one: '1 producto añadido a la lista de la compra',
    );
    return '$_temp0';
  }

  @override
  String get mealsRecipesTitle => 'Recetas';

  @override
  String get mealsRecipeSearch => 'Buscar recetas';

  @override
  String get mealsRecipesEmpty =>
      'Aún no hay recetas. Para planificar una comida basta con el nombre del plato; una receta añade sus ingredientes a la lista de la compra.';

  @override
  String get mealsRecipeNew => 'Nueva receta';

  @override
  String get mealsRecipeEdit => 'Editar receta';

  @override
  String get mealsRecipeTitleField => 'Título';

  @override
  String get mealsIngredients => 'Ingredientes';

  @override
  String get mealsIngredientName => 'Ingrediente';

  @override
  String get mealsIngredientQuantity => 'Cantidad';

  @override
  String get mealsIngredientUnit => 'Unidad';

  @override
  String get mealsIngredientNote => 'Nota';

  @override
  String get mealsIngredientAdd => 'Añadir ingrediente';

  @override
  String get mealsIngredientRemove => 'Quitar ingrediente';

  @override
  String get mealsIngredientMove => 'Arrastrar para reordenar';

  @override
  String get mealsNoIngredients => 'No hay ingredientes indicados.';

  @override
  String get mealsSteps => 'Preparación';

  @override
  String get mealsStepsHint => 'Un paso por línea';

  @override
  String get mealsTags => 'Etiquetas';

  @override
  String get mealsTagsHint =>
      'Separadas por comas, p. ej., rápido, vegetariano';

  @override
  String get mealsSourceUrl => 'Enlace de origen';

  @override
  String get mealsSource => 'Origen';

  @override
  String get mealsRecipeSave => 'Guardar receta';

  @override
  String get mealsRecipeDelete => 'Eliminar receta';

  @override
  String mealsRecipeDeleteConfirm(String title) {
    return '¿Eliminar «$title»? Las comidas que usan esta receta conservarán su nombre.';
  }

  @override
  String get mealsRecipeTitleRequired => 'La receta necesita un título.';

  @override
  String get mealsKioskHint => 'Toca un punto para cambiar quién come en casa';

  @override
  String get errMealInvalid =>
      'No se ha podido guardar esta comida. Revisa los datos e inténtalo de nuevo.';

  @override
  String get schoolSetupCardTitle => 'Configurar el colegio';

  @override
  String get schoolSetupCardBody =>
      'Añade el colegio. Las horas de clase y las asignaturas se proponen; después introduce el horario o impórtalo.';

  @override
  String get schoolSetupAction => 'Configurar colegio';

  @override
  String get schoolEnterTimetableTitle => 'Introducir el horario';

  @override
  String schoolEnterTimetableBody(String name) {
    return '$name aún no tiene horario para la semana mostrada.';
  }

  @override
  String get schoolEnterTimetableAction => 'Introducir horario';

  @override
  String get schoolNoChildren => 'Aún no hay niños en el hogar.';

  @override
  String get schoolEditSchool => 'Editar colegio';

  @override
  String get schoolEditTimetable => 'Editar horario';

  @override
  String get schoolPrevWeek => 'Semana anterior';

  @override
  String get schoolNextWeek => 'Semana siguiente';

  @override
  String get schoolThisWeek => 'Esta semana';

  @override
  String schoolWeekLabel(int week, String from, String to) {
    return 'Semana $week · $from – $to';
  }

  @override
  String get schoolChooseChild => 'Elegir niño o niña';

  @override
  String schoolHolidayBand(String name, String range) {
    return '$name · $range';
  }

  @override
  String get schoolNoLessonsToday => 'Sin clases';

  @override
  String get schoolPackTomorrowNone => 'No hay nada que preparar para mañana.';

  @override
  String schoolLessonActions(String subject, String day, String period) {
    return '$subject, $day, $period';
  }

  @override
  String get schoolCancelLesson => 'Cancelada';

  @override
  String get schoolSubstitute => 'Suplencia';

  @override
  String get schoolRoomChange => 'Cambio de aula';

  @override
  String get schoolResetException => 'Restablecer';

  @override
  String get schoolPickSubject => 'Asignatura';

  @override
  String get schoolSearchSubject => 'Buscar asignatura';

  @override
  String get schoolTeacher => 'Docente';

  @override
  String get schoolNote => 'Nota';

  @override
  String get schoolRoom => 'Aula';

  @override
  String get schoolApply => 'Aplicar';

  @override
  String get schoolSaved => 'Guardado.';

  @override
  String get schoolNoSubjects =>
      'Aún no hay asignaturas. Añádelas en la configuración del colegio.';

  @override
  String get schoolSetupTitle => 'Colegio';

  @override
  String get schoolSectionSchool => 'Colegio';

  @override
  String get schoolName => 'Nombre del colegio';

  @override
  String get schoolBellTimes => 'Horas de clase y recreo';

  @override
  String get schoolAddLesson => 'Añadir clase';

  @override
  String get schoolAddBreak => 'Añadir recreo';

  @override
  String get schoolRemove => 'Quitar';

  @override
  String get schoolStart => 'Inicio';

  @override
  String get schoolEnd => 'Fin';

  @override
  String get schoolTerms => 'Periodos lectivos';

  @override
  String get schoolAddTerm => 'Añadir periodo lectivo';

  @override
  String get schoolTermEdit => 'Editar periodo';

  @override
  String get schoolTermNew => 'Nuevo periodo';

  @override
  String get schoolTermName => 'Nombre';

  @override
  String get schoolTermNameHint => 'p. ej. Curso 2026/27 o 1.er trimestre';

  @override
  String get schoolFrom => 'Desde';

  @override
  String get schoolTo => 'Hasta';

  @override
  String get schoolTermPickDate => 'Elegir una fecha';

  @override
  String get schoolTermEndBeforeStart => 'Termina antes de empezar';

  @override
  String schoolTermMustCoverWeek(String week) {
    return 'Debe incluir la semana mostrada ($week)';
  }

  @override
  String get schoolAbWeeks => 'Semanas A y B';

  @override
  String get schoolAbWeeksHint => 'Actívalo si el horario alterna cada semana.';

  @override
  String get schoolAbWeek => 'Número de semana de una semana A';

  @override
  String get schoolAbWeekHint =>
      'Número de semana, por ejemplo 43. Después se alternan B, A, B…';

  @override
  String schoolAbWeekShown(int week) {
    return 'La semana mostrada es la semana $week.';
  }

  @override
  String get schoolAbWeekInvalid => 'Introduce un número de semana del 1 al 53';

  @override
  String get schoolCurrent => 'actual';

  @override
  String get schoolCurrentTerm => 'Periodo actual';

  @override
  String get schoolCurrentTermHint =>
      'Marca el periodo en el que estáis ahora. Solo uno por escuela.';

  @override
  String get schoolSubjects => 'Asignaturas';

  @override
  String get schoolAddSubject => 'Añadir asignatura';

  @override
  String get schoolSubjectEdit => 'Asignatura';

  @override
  String get schoolSubjectShort => 'Abreviatura';

  @override
  String get schoolTint => 'Color';

  @override
  String get schoolEquipment => 'Material que hay que llevar';

  @override
  String get schoolNotable => 'Mostrar en el panel de pared';

  @override
  String get schoolSubjectInUse =>
      'Esta asignatura sigue en un horario. Quítala de allí primero.';

  @override
  String get schoolInvalid => 'Estos datos no encajan entre sí.';

  @override
  String get schoolHolidays => 'Vacaciones y días libres';

  @override
  String get schoolAddHoliday => 'Añadir vacaciones';

  @override
  String get schoolHolidayEdit => 'Vacaciones';

  @override
  String get schoolHolidayName => 'Nombre';

  @override
  String get schoolEditorClass => 'Clase';

  @override
  String get schoolWeekCycle => 'Ciclo semanal';

  @override
  String get schoolCycleWeekly => 'Cada semana';

  @override
  String get schoolCycleAb => 'Semanas A/B';

  @override
  String get schoolParityAll => 'Cada semana';

  @override
  String get schoolParityA => 'Semana A';

  @override
  String get schoolParityB => 'Semana B';

  @override
  String get schoolClearDay => 'Vaciar día';

  @override
  String get schoolClearCell => 'Vaciar';

  @override
  String get schoolCopyFrom => 'Copiar de…';

  @override
  String get schoolCopyPick => 'Copiar el horario de';

  @override
  String get schoolCareRows => 'Cuidado extraescolar';

  @override
  String get schoolAddCare => 'Añadir cuidado infantil';

  @override
  String get schoolCareTitle => 'Nombre';

  @override
  String get schoolCareDays => 'Los días';

  @override
  String get schoolSaveTimetable => 'Guardar horario';

  @override
  String get schoolWeekdayPick => 'Días';

  @override
  String get feedTitle => 'Compartir el calendario familiar';

  @override
  String get feedSettingsSubtitle => 'Solo lectura, en Outlook o en un iPhone';

  @override
  String get feedNew => 'Nueva suscripción';

  @override
  String get feedEmpty =>
      'Aún no hay suscripciones. Una suscripción muestra las citas en Outlook o en un iPhone, sin permitir cambios.';

  @override
  String get feedRevoked => 'Revocada';

  @override
  String get feedNeverFetched => 'Nunca consultada';

  @override
  String feedLastFetched(String when) {
    return 'Última consulta: $when';
  }

  @override
  String get feedAgoJustNow => 'ahora mismo';

  @override
  String feedAgoMinutes(int count) {
    return 'hace $count min';
  }

  @override
  String feedAgoHours(int count) {
    return 'hace $count h';
  }

  @override
  String feedAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count días',
      one: 'hace 1 día',
    );
    return '$_temp0';
  }

  @override
  String feedFetchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'consultada $count veces',
      one: 'consultada una vez',
    );
    return '$_temp0';
  }

  @override
  String get feedSummaryAppointments => 'Citas';

  @override
  String get feedSummaryPresence => 'Presencia';

  @override
  String get feedSummaryEveryone => 'Todos los miembros';

  @override
  String get feedSummarySchoolDay => 'Día lectivo';

  @override
  String get feedSummarySchoolLessons => 'Clases';

  @override
  String get feedWhoseTitle => 'De quién son los eventos';

  @override
  String get feedWhoseHelp => 'Sin selección: todos';

  @override
  String get feedLabelField => 'Nombre de la suscripción';

  @override
  String get feedLabelHint => 'p. ej., Outlook del portátil del trabajo';

  @override
  String get feedWhatTitle => 'Qué incluir';

  @override
  String get feedKindPresenceTitle => 'Presencia';

  @override
  String get feedPresenceHint =>
      'Muestra quién está dónde y cuándo (trabajo, teletrabajo, día libre…). Es mejor desactivarlo para dispositivos del trabajo y de los niños.';

  @override
  String get feedSchoolTitle => 'Colegio';

  @override
  String get feedSchoolOff => 'Desactivado';

  @override
  String get feedSchoolHint =>
      'Los días lectivos como una entrada de todo el día o cada clase por separado.';

  @override
  String get feedCreate => 'Crear suscripción';

  @override
  String get feedUrlTitle => 'Dirección de la suscripción';

  @override
  String get feedUrlOnce =>
      'Esta dirección solo se muestra una vez. Cualquiera que la tenga podrá ver los eventos, así que trátala como una contraseña.';

  @override
  String get feedCopyUrl => 'Copiar dirección';

  @override
  String get feedCopyWebcal => 'Copiar enlace webcal';

  @override
  String get feedWebcalLabel => 'Enlace webcal (abre el diálogo del iPhone)';

  @override
  String get feedCopied => 'Dirección copiada.';

  @override
  String get feedQrLabel => 'Código QR con la dirección de la suscripción';

  @override
  String get feedHowTitle => 'Cómo suscribirte';

  @override
  String get feedHowOutlook =>
      'Outlook en la web: Calendario → Agregar calendario → Suscribirse desde la web → pega la dirección → ponle el nombre «Familia».';

  @override
  String get feedHowIphone =>
      'iPhone: Ajustes → Apps → Calendario → Cuentas → Añadir cuenta → Otra → Añadir calendario suscrito → pega la dirección. O toca el enlace webcal.';

  @override
  String get feedRevokeAction => 'Revocar';

  @override
  String feedRevokeConfirm(String label) {
    return '¿Revocar «$label»? Dejará de recibir eventos de inmediato.';
  }

  @override
  String get baselineTitle => 'Semana habitual';

  @override
  String get baselineSettingsSubtitle =>
      'Dónde suele estar cada persona, día a día';

  @override
  String get baselineHelp =>
      'Dónde sueles estar cada día de la semana. Solo se introducen los cambios, así que una semana normal queda vacía.';

  @override
  String get baselineNone => 'Sin definir';

  @override
  String get baselineLabelField => 'Etiqueta propia (opcional)';

  @override
  String get baselineLabelHint => 'p. ej., en casa';

  @override
  String get baselineSaved => 'Guardado.';

  @override
  String get usualCopyMonday => 'De martes a viernes como el lunes';

  @override
  String usualDayTitle(String name, String weekday) {
    return '$name el $weekday';
  }

  @override
  String get usualDayApply => 'Aplicar';

  @override
  String get usualWholeDay => 'Todo el día';

  @override
  String get usualSlots => 'Franjas horarias';

  @override
  String get usualSlotState => 'Dónde';

  @override
  String get usualSlotFrom => 'Desde';

  @override
  String get usualSlotUntil => 'Hasta';

  @override
  String get usualAddSlot => 'Añadir franja horaria';

  @override
  String get usualRemoveSlot => 'Quitar franja horaria';

  @override
  String get usualSlotsInvalid =>
      'Cada franja termina después de empezar y las franjas no se solapan.';

  @override
  String get usualAlternating => 'Semanas alternas (A/B)';

  @override
  String get usualAlternatingHelp =>
      'Para un plan que se repite cada dos semanas.';

  @override
  String get usualWeekA => 'Semana A';

  @override
  String get usualWeekB => 'Semana B';

  @override
  String usualThisWeekIs(String week) {
    return 'Esta semana: $week.';
  }

  @override
  String get usualWhichWeek => '¿Qué semana es esta?';

  @override
  String get errUsualWeekInvalid => 'Esta semana habitual no es válida.';

  @override
  String get busyTitle => 'Reuniones hasta';

  @override
  String get busyPickTime => 'Elegir hora';

  @override
  String get busyThisDay => 'Solo este día';

  @override
  String get busyWholeWeek => 'Aplicar a toda la semana (lun–vie)';

  @override
  String get busyRemove => 'Quitar';

  @override
  String get busyHelp =>
      'Hasta cuándo no estás disponible. Solo la hora: sin citas ni detalles.';

  @override
  String get busyFor => 'Para';

  @override
  String get tasksTabToday => 'Hoy';

  @override
  String get tasksTabApprovals => 'Aprobaciones';

  @override
  String get tasksTabChores => 'Tareas';

  @override
  String get tasksTabRewards => 'Recompensas';

  @override
  String get tasksTabPoints => 'Puntos';

  @override
  String get tasksNothingToday => 'No hay tareas para hoy.';

  @override
  String get tasksOpenForAnyone => 'Disponible para cualquiera';

  @override
  String get tasksWaitingApproval => 'pendiente de aprobación';

  @override
  String get tasksDone => 'Hecho';

  @override
  String get tasksUndo => 'Deshacer';

  @override
  String tasksCompletedSnack(String title) {
    return '$title: hecho';
  }

  @override
  String tasksPointsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count puntos',
      one: '1 punto',
    );
    return '$_temp0';
  }

  @override
  String tasksStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días seguidos',
      one: '1 día seguido',
    );
    return '$_temp0';
  }

  @override
  String tasksOpenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pendientes',
      one: '1 pendiente',
      zero: 'ninguna pendiente',
    );
    return '$_temp0';
  }

  @override
  String get tasksKindDuty => 'Obligatoria';

  @override
  String get tasksKindBonus => 'Extra';

  @override
  String get tasksApprovalsEmpty => 'No hay nada que revisar.';

  @override
  String get tasksCheckChores => 'Tareas por revisar';

  @override
  String get tasksRewardRequests => 'Solicitudes de recompensas';

  @override
  String get tasksApprove => 'Aprobar';

  @override
  String get tasksDecline => 'Rechazar';

  @override
  String tasksRequestedBy(String name, String reward) {
    return '$name quiere $reward';
  }

  @override
  String tasksDoneBy(String name) {
    return 'Hecho por $name';
  }

  @override
  String get tasksNoteOptional => 'Nota (opcional)';

  @override
  String get tasksNoChores => 'Aún no hay tareas.';

  @override
  String get tasksStarterHelp =>
      'Cinco tareas, tres recompensas y cuatro insignias para empezar. Después se puede cambiar todo.';

  @override
  String get tasksStarterAdd => 'Añadir paquete inicial';

  @override
  String get tasksStarterDone => 'Paquete inicial añadido.';

  @override
  String get tasksNewChore => 'Nueva tarea';

  @override
  String get tasksEditChore => 'Editar tarea';

  @override
  String get tasksFieldTitle => 'Título';

  @override
  String get tasksTitleRequired => 'Introduce un título.';

  @override
  String get tasksFieldIcon => 'Icono';

  @override
  String get taskIcon_dishes => 'Plato';

  @override
  String get taskIcon_table => 'Cuchara';

  @override
  String get taskIcon_trash => 'Cubo de basura';

  @override
  String get taskIcon_bed => 'Cama';

  @override
  String get taskIcon_dog => 'Perro';

  @override
  String get taskIcon_plant => 'Planta';

  @override
  String get taskIcon_bike => 'Bicicleta';

  @override
  String get taskIcon_book => 'Libros';

  @override
  String get taskIcon_laundry => 'Cesto de ropa';

  @override
  String get taskIcon_teeth => 'Cepillo de dientes';

  @override
  String get taskIcon_shopping => 'Carrito de la compra';

  @override
  String get taskIcon_cooking => 'Sartén';

  @override
  String get taskIcon_car => 'Coche';

  @override
  String get taskIcon_toys => 'Osito de peluche';

  @override
  String get taskIcon_star => 'Estrella';

  @override
  String get taskIcon_cinema => 'Película';

  @override
  String get taskIcon_moon => 'Luna';

  @override
  String get taskIcon_trip => 'Brújula';

  @override
  String get tasksNoIcon => 'Sin icono';

  @override
  String get tasksFieldKind => 'Tipo';

  @override
  String get tasksKindDutyHelp => 'Corresponde a todos; da pocos puntos.';

  @override
  String get tasksKindBonusHelp => 'Trabajo extra voluntario; da puntos.';

  @override
  String get tasksFieldPoints => 'Puntos';

  @override
  String get tasksFieldRepeat => 'Repetir';

  @override
  String get tasksRepeatOnce => 'Una vez';

  @override
  String get tasksRepeatDaily => 'Cada día';

  @override
  String get tasksRepeatWeekdays => 'En días de la semana';

  @override
  String get tasksRepeatWeekly => 'Cada semana';

  @override
  String get tasksRepeatBiweekly => 'Cada 2 semanas';

  @override
  String get tasksRepeatMonthly => 'Cada mes';

  @override
  String get tasksWeekdayOne => 'Día de la semana';

  @override
  String get tasksWeekdayMany => 'Días de la semana';

  @override
  String get tasksWeekdaysRequired => 'Elige al menos un día de la semana.';

  @override
  String get tasksFieldStarts => 'Empieza el';

  @override
  String get tasksFieldWindow => 'Se puede hacer';

  @override
  String tasksWindowDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Durante $count días desde el día previsto',
      one: 'Solo el día previsto',
    );
    return '$_temp0';
  }

  @override
  String get tasksFieldWho => 'Quién';

  @override
  String get tasksWhoFixed => 'Una persona';

  @override
  String get tasksWhoRotating => 'Por turnos';

  @override
  String get tasksWhoOpen => 'Quien quiera';

  @override
  String get tasksWhoEach => 'Cada persona';

  @override
  String get tasksPickOne => '¿Quién la hace?';

  @override
  String get tasksPickPool => '¿Quién participa?';

  @override
  String get tasksPickOpenPool =>
      '¿Quién puede hacerla? En blanco significa todos.';

  @override
  String get tasksPoolRequired => 'Elige al menos una persona.';

  @override
  String get tasksFieldVerification => 'Aprobación de un adulto';

  @override
  String get tasksVerificationHelp =>
      'Los puntos se suman después de revisar la tarea.';

  @override
  String get tasksArchive => 'Archivar';

  @override
  String get tasksArchiveHelp =>
      'La tarea desaparece. Se eliminan sus entradas futuras pendientes.';

  @override
  String get tasksNoRewards => 'Aún no hay recompensas.';

  @override
  String get tasksNewReward => 'Nueva recompensa';

  @override
  String get tasksEditReward => 'Editar recompensa';

  @override
  String get tasksFieldCost => 'Coste en puntos';

  @override
  String get tasksFieldStock => 'Existencias (en blanco: ilimitadas)';

  @override
  String get tasksFieldNeedsApproval => 'Necesita aprobación previa';

  @override
  String get tasksNeedsApprovalHelp =>
      'Desactívalo solo para pequeñas recompensas.';

  @override
  String get tasksAskForReward => 'Pedir recompensa';

  @override
  String get tasksRequestSent => 'Solicitud enviada.';

  @override
  String get tasksRedeemed => 'Canjeado.';

  @override
  String get tasksSoldOut => 'Agotado';

  @override
  String tasksMissingPoints(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Faltan $count puntos',
      one: 'Falta 1 punto',
    );
    return '$_temp0';
  }

  @override
  String get tasksHistory => 'Historial';

  @override
  String get tasksNoHistory => 'Aún no se ha canjeado nada.';

  @override
  String get tasksRedemptionRequested => 'Pendiente de aprobación';

  @override
  String get tasksRedemptionApproved => 'Canjeado, aún sin entregar';

  @override
  String get tasksRedemptionDeclined => 'Rechazado';

  @override
  String get tasksRedemptionFulfilled => 'Entregado';

  @override
  String get tasksHandOver => 'Marcar como entregado';

  @override
  String get tasksNoLedger => 'Aún no hay movimientos.';

  @override
  String get tasksLedgerTask => 'Tarea completada';

  @override
  String get tasksLedgerUndo => 'Anulado';

  @override
  String get tasksLedgerRedemption => 'Recompensa';

  @override
  String get tasksLedgerAdjustment => 'Corrección';

  @override
  String get tasksLedgerBadge => 'Insignia';

  @override
  String get tasksLedgerBonus => 'Puntos extra';

  @override
  String get tasksAdjust => 'Corregir';

  @override
  String tasksAdjustTitle(String name) {
    return 'Corregir los puntos de $name';
  }

  @override
  String get tasksFieldAmount => 'Puntos (+ o −)';

  @override
  String get tasksAmountInvalid => 'Introduce un número distinto de 0.';

  @override
  String get tasksFieldReason => 'Motivo (obligatorio)';

  @override
  String get tasksReasonRequired => 'Indica un motivo.';

  @override
  String get tasksBalanceTitle => 'Saldo';

  @override
  String get tasksBoardStreakLabel => 'Racha';

  @override
  String get errTaskInvalid => 'Esta tarea no es válida.';

  @override
  String get errTaskNotYours =>
      'Solo puede hacerlo la persona a la que corresponde.';

  @override
  String get errBalanceInsufficient => 'No hay puntos suficientes.';

  @override
  String get errRewardOutOfStock => 'Esta recompensa está agotada.';

  @override
  String get errTaskNotOpen => 'Esta tarea ya no está pendiente.';

  @override
  String get tasksActionTick => 'Marcar como hecha';

  @override
  String get tasksPointsInvalid =>
      'Introduce un número entero igual o mayor que 0.';

  @override
  String get kidTabToday => 'Mi día';

  @override
  String get kidTabSchool => 'Horario';

  @override
  String get kidTabPoints => 'Puntos';

  @override
  String get kidTabShopping => 'Compra';

  @override
  String get kidTabFamily => 'Familia';

  @override
  String get kidWhoAreYou => '¡Hola! Toca tu nombre.';

  @override
  String kidGreeting(String name) {
    return '¡Hola, $name!';
  }

  @override
  String get kidTasksTitle => 'Mis tareas';

  @override
  String get kidTasksNone => 'Hoy no tienes tareas.';

  @override
  String get kidTasksAllDone => '¡Todo hecho!';

  @override
  String get kidTasksAllDoneBody =>
      '¡Muy bien! Ya has terminado todo lo de hoy.';

  @override
  String get kidAwaitsCheck => 'pendiente de revisión';

  @override
  String get kidDone => 'Hecho';

  @override
  String kidTaskDoneSnack(String title) {
    return '¡$title: hecho!';
  }

  @override
  String get kidUndo => 'Deshacer';

  @override
  String get kidSchoolTitle => 'Hoy en el colegio';

  @override
  String get kidNoSchoolToday => 'Hoy no hay colegio.';

  @override
  String kidHoliday(String name) {
    return 'Vacaciones: $name';
  }

  @override
  String get kidNoTimetable => 'Aún no han introducido tu horario.';

  @override
  String kidRoom(String room) {
    return 'Aula $room';
  }

  @override
  String get kidNow => 'Ahora';

  @override
  String get kidLessonCancelled => 'cancelada';

  @override
  String get kidLessonSubstituted => 'docente suplente';

  @override
  String get kidLessonRoomChange => 'otra aula';

  @override
  String kidCareUntil(String time) {
    return 'Cuidado infantil hasta las $time';
  }

  @override
  String kidTomorrowNeeds(String items) {
    return 'Mañana necesitas: $items';
  }

  @override
  String kidMealDinner(String dish) {
    return 'Esta noche cenamos $dish';
  }

  @override
  String kidMealLunch(String dish) {
    return 'Hoy almorzamos $dish';
  }

  @override
  String get kidMealNoneDinner => 'Aún no hay nada previsto para cenar.';

  @override
  String get kidMealNoneLunch => 'Aún no hay nada previsto para almorzar.';

  @override
  String get kidMealEatingYou => 'Tú también comes en casa.';

  @override
  String get kidEventsTitle => 'Mis citas de hoy';

  @override
  String get kidNoEvents => 'Hoy no tienes citas.';

  @override
  String get kidAllDay => 'todo el día';

  @override
  String get kidTimetableTitle => 'Mi horario';

  @override
  String get kidTodayMarker => 'Hoy';

  @override
  String get kidYourPoints => 'Tus puntos';

  @override
  String get kidRewardsTitle => 'Recompensas';

  @override
  String get kidRedeem => 'Canjear';

  @override
  String kidNeedMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Te faltan $count puntos',
      one: 'Te falta 1 punto',
    );
    return '$_temp0';
  }

  @override
  String get kidWaitsApproval => 'pendiente de aprobación';

  @override
  String get kidRequestSent => 'Tu recompensa está pendiente de aprobación.';

  @override
  String get kidRedeemed => '¡Canjeado!';

  @override
  String get kidSoldOut => 'Agotado por ahora';

  @override
  String get kidBadgesTitle => 'Mis insignias';

  @override
  String get kidBadgeEarned => 'Conseguida';

  @override
  String get kidBadgeNotYet => 'Aún no conseguida';

  @override
  String get kidStreaksTitle => 'Mis rachas';

  @override
  String kidStreak(int days, String title) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days días $title',
      one: '1 día $title',
    );
    return '$_temp0';
  }

  @override
  String get kidFamilyTitle => 'La familia hoy';

  @override
  String kidOpenTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tareas pendientes',
      one: '1 tarea pendiente',
      zero: 'No hay tareas pendientes',
    );
    return '$_temp0';
  }

  @override
  String get kidNoPlanToday => 'Nada previsto para hoy';

  @override
  String get schoolsUiAddSchool => 'Otro colegio';

  @override
  String get schoolsUiNewSchool => 'Nuevo colegio';

  @override
  String get schoolsUiPickSchool => 'Elegir colegio';

  @override
  String get schoolsUiAskSchool => '¿Qué colegio?';

  @override
  String schoolsUiSchoolOf(String name) {
    return 'Colegio: $name';
  }

  @override
  String get schoolsUiDayMenu => 'Acciones del día';

  @override
  String get schoolsUiCopyDay => 'Copiar día a…';

  @override
  String schoolsUiCopyDayTitle(String day) {
    return 'Copiar $day a';
  }

  @override
  String get schoolsUiCopyDayApply => 'Copiar';

  @override
  String get schoolsUiSwapDay => 'Intercambiar con…';

  @override
  String schoolsUiSwapDayTitle(String day) {
    return 'Intercambiar $day con';
  }

  @override
  String get schoolsUiDayCleared => 'Día vaciado';

  @override
  String get schoolsUiDayCopied => 'Día copiado';

  @override
  String get schoolsUiDaySwapped => 'Días intercambiados';

  @override
  String get schoolsUiUndo => 'Deshacer';

  @override
  String get mealsUxSuggestOften => 'Favoritos de la familia';

  @override
  String get mealsUxSuggestRare => 'Hace tiempo que no lo comemos';

  @override
  String mealsUxClearedSnack(String title) {
    return '$title: eliminado';
  }

  @override
  String get mealsUxUndo => 'Deshacer';

  @override
  String get mealsUxFromMealPlan => 'Del plan de comidas';

  @override
  String mealsUxForMeal(String meal, String day) {
    return 'Para: $meal · $day';
  }

  @override
  String get todayTitle => 'Hoy';

  @override
  String get todayEmpty =>
      'Aún no hay nada previsto para hoy. Disfruta de la tranquilidad.';

  @override
  String get todayAgendaTitle => 'Citas';

  @override
  String get todayAllDay => 'todo el día';

  @override
  String get todayTasksTitle => 'Tus tareas de hoy';

  @override
  String get todayMealTitle => 'Comida caliente';

  @override
  String todayMealLine(String slot, String dish) {
    return '$slot: $dish';
  }

  @override
  String get todayShoppingTitle => 'Lista de la compra';

  @override
  String todayShoppingOpen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count productos pendientes',
      one: '1 producto pendiente',
    );
    return '$_temp0';
  }

  @override
  String todayNoticeJoined(String name) {
    return '$name se ha unido';
  }

  @override
  String todayNoticeSignIn(String device) {
    return 'Nuevo inicio de sesión: $device';
  }

  @override
  String get todayNoticeDismiss => 'Entendido';

  @override
  String get todayNoticeMembers => 'Miembros';

  @override
  String get todayNoticeDevices => 'Dispositivos';

  @override
  String get todayApprovalsTitle => 'Pendiente de tu aprobación';

  @override
  String todayApprovalsChecks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tareas por revisar',
      one: '1 tarea por revisar',
    );
    return '$_temp0';
  }

  @override
  String todayApprovalsRequests(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count solicitudes de recompensa',
      one: '1 solicitud de recompensa',
    );
    return '$_temp0';
  }

  @override
  String get todayStartTitle => 'Primeros pasos';

  @override
  String todayStartProgress(int done, int total) {
    return '$done de $total';
  }

  @override
  String get todayStartNotNeeded => 'No lo necesitamos';

  @override
  String get todayStartInvitePartner => 'Invita a tu pareja';

  @override
  String get todayStartConnectTablet => 'Conecta la tableta familiar';

  @override
  String get todayStartWallDisplay => 'Configura la pantalla de pared';

  @override
  String get todayStartSetPin => 'Establece tu PIN';

  @override
  String get todayStartSubscribeFeed => 'Suscríbete al calendario';

  @override
  String get todayStartSchool => 'Añade el horario escolar';

  @override
  String get settingsGettingStarted => 'Primeros pasos';

  @override
  String get settingsGettingStartedSubtitle =>
      'Volver a mostrar la tarjeta de configuración en la pestaña Hoy';

  @override
  String get settingsLicenses => 'Licencias de código abierto';

  @override
  String get settingsLicensesSubtitle =>
      'Las licencias del software y las fuentes con los que está hecho WuselWall';

  @override
  String get exportFamilyTitle => 'Familia';

  @override
  String get exportAction => 'Exportar datos';

  @override
  String get exportExplanation =>
      'Todos los datos de vuestra familia en un archivo, por ejemplo para trasladarlos a otro servidor.';

  @override
  String get exportInProgress => 'Exportando datos';

  @override
  String get exportPersonalDeviceRequired =>
      'Solo puedes exportar desde tu propio teléfono.';

  @override
  String boardHolidayLabel(String name) {
    return 'Festivo · $name';
  }

  @override
  String get regionSettingTitle => 'Región';

  @override
  String get regionSettingHelp =>
      'Determina los festivos que se aplican y las vacaciones escolares que puedes importar. Elige el cantón, estado o municipio.';

  @override
  String get regionFieldLabel => 'Región';

  @override
  String get regionFieldEmpty => 'Sin región seleccionada';

  @override
  String get regionFieldClear => 'Quitar región';

  @override
  String get regionCountryDE => 'Alemania';

  @override
  String get regionCountryAT => 'Austria';

  @override
  String get regionCountryCH => 'Suiza';

  @override
  String get regionCountryLI => 'Liechtenstein';

  @override
  String get regionCountryOther => 'Otro país (sin región)';

  @override
  String get regionPickCountryTitle => 'País';

  @override
  String get regionPickRegionTitle => 'Cantón o estado';

  @override
  String get regionPickSearch => 'Buscar';

  @override
  String regionPickWholeRegion(String name) {
    return 'Toda la región: $name';
  }

  @override
  String get regionPickDeeperTitle => 'Concretar más (distrito o municipio)';

  @override
  String get regionPickDeeperSearch => 'Escribe un municipio o distrito';

  @override
  String get regionPickNoMatch => 'No se ha encontrado nada';

  @override
  String get regionPickLoading => 'Cargando regiones…';

  @override
  String get regionPickRetry => 'Volver a intentar';

  @override
  String get regionPickSkip => 'Continuar sin región';

  @override
  String get regionPickEmpty => 'No hay regiones para este país.';

  @override
  String get regionUnavailable =>
      'La lista de regiones no está disponible ahora. Comprueba la conexión e inténtalo de nuevo.';

  @override
  String get regionCategoryCanton => 'Cantón';

  @override
  String regionNameWithAbbreviation(String name, String abbreviation) {
    return '$name ($abbreviation)';
  }

  @override
  String regionNameTop(String category, String name) {
    return '$category $name';
  }

  @override
  String regionNameDeeper(String name, String category, String parent) {
    return '$name ($category), $parent';
  }

  @override
  String get regionImportAction => 'Importar vacaciones escolares';

  @override
  String get regionImportNeedsRegion =>
      'Primero elige una región para el colegio.';

  @override
  String get regionImportTitle => 'Vacaciones escolares';

  @override
  String get regionImportIntro =>
      'Los festivos de la región se aplican automáticamente. Aquí puedes importar las vacaciones escolares.';

  @override
  String get regionImportSwissHint =>
      'En Suiza, las vacaciones escolares pueden variar según el municipio. Comprueba las fechas.';

  @override
  String get regionImportNone =>
      'No se han encontrado vacaciones escolares en los próximos 18 meses.';

  @override
  String get regionImportAlready => 'ya importado';

  @override
  String get regionImportOverlaps => 'coincide con una entrada propia';

  @override
  String get regionImportButton => 'Importar';

  @override
  String regionImportDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count periodos de vacaciones importados',
      one: '1 periodo de vacaciones importado',
      zero: 'No se han importado vacaciones',
    );
    return '$_temp0';
  }

  @override
  String get regionImportAttribution => 'Datos: OpenHolidays API · ODbL';

  @override
  String get regionImported => 'importado';

  @override
  String get extCalTitle => 'Añadir calendarios externos';

  @override
  String get extCalSettingsSubtitle =>
      'Partidos, recogida de basura y más en el calendario familiar';

  @override
  String get extCalEmpty =>
      'Aún no hay calendarios suscritos. Una suscripción incorpora citas externas al calendario familiar, como los partidos de un club.';

  @override
  String get extCalNew => 'Suscribirse a un calendario';

  @override
  String get extCalNewTitle => 'Nuevo calendario';

  @override
  String get extCalEditTitle => 'Editar calendario';

  @override
  String get extCalEdit => 'Editar';

  @override
  String get extCalNameLabel => 'Nombre';

  @override
  String get extCalNameHint => 'p. ej., partidos del club';

  @override
  String get extCalNameRequired => 'Pon un nombre al calendario.';

  @override
  String get extCalUrlLabel => 'Dirección (ICS)';

  @override
  String get extCalUrlHelp =>
      'La dirección donde se publica el calendario, normalmente terminada en .ics. Por ejemplo, el calendario de recogida de basura del municipio o los partidos del club. También se admiten direcciones webcal://.';

  @override
  String get extCalUrlInvalid =>
      'Esto no parece una dirección web (https://…).';

  @override
  String get extCalColourLabel => 'Color';

  @override
  String extCalColourOption(int number) {
    return 'Color $number';
  }

  @override
  String get extCalMembersLabel => '¿Para quién?';

  @override
  String get extCalMembersHelp =>
      'Sin selección, el calendario es para toda la familia.';

  @override
  String get extCalMembersWhole => 'Toda la familia';

  @override
  String get extCalShowOnBoard => 'Mostrar en la pantalla de la cocina';

  @override
  String get extCalShowOnBoardHelp =>
      'Sus citas aparecerán como citas importantes en el panel semanal de la pantalla de la cocina.';

  @override
  String extCalDeleteConfirm(String name) {
    return 'Se eliminarán «$name» y todas sus citas.';
  }

  @override
  String get extCalDeleted => 'Calendario eliminado.';

  @override
  String get extCalRefreshNow => 'Actualizar ahora';

  @override
  String extCalRefreshed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count citas cargadas',
      one: '1 cita cargada',
      zero: 'No se han encontrado citas',
    );
    return '$_temp0';
  }

  @override
  String get extCalNotModified => 'No hay cambios desde la última consulta.';

  @override
  String get extCalRecent =>
      'Se ha consultado hace un momento. Inténtalo de nuevo en unos minutos.';

  @override
  String extCalRefreshFailed(String reason) {
    return 'No se ha podido cargar el calendario: $reason';
  }

  @override
  String get extCalStatusPaused => 'En pausa';

  @override
  String get extCalStatusNever => 'Cargando por primera vez…';

  @override
  String extCalStatusUpdated(String when) {
    return 'Actualizado $when';
  }

  @override
  String get extCalReadOnlyHint =>
      'Solo los responsables pueden suscribirse a calendarios o cambiarlos.';

  @override
  String get extCalErrUnreachable =>
      'No se puede acceder a esta dirección ahora.';

  @override
  String get extCalErrTimeout => 'La dirección tarda demasiado en responder.';

  @override
  String get extCalErrForbiddenHost => 'Esta dirección no está permitida.';

  @override
  String get extCalErrTooLarge =>
      'El calendario es demasiado grande (más de 2 MB).';

  @override
  String get extCalErrNotIcs => 'Esto no es un calendario (ICS).';

  @override
  String get extCalErrHttp404 => 'Dirección no encontrada (404).';

  @override
  String extCalErrHttp(int status) {
    return 'La dirección responde con el error $status.';
  }

  @override
  String get extCalErrInternal =>
      'Algo ha fallado en el servidor. Inténtalo más tarde.';

  @override
  String get extCalErrDb => 'No se han podido guardar las citas.';

  @override
  String get extCalErrUnknown => 'La consulta no ha funcionado.';

  @override
  String get extCalErrInvalid =>
      'Los datos del calendario no son válidos: revisa el nombre y el color.';

  @override
  String get extCalErrUrlInvalid =>
      'No se puede guardar esta dirección. Debe empezar por https://.';

  @override
  String get extCalErrNotFound => 'Este calendario ya no existe.';

  @override
  String get extCalImportedNote =>
      'Calendario suscrito: los cambios proceden del origen';

  @override
  String extCalFromCalendar(String name) {
    return 'De $name';
  }

  @override
  String get extCalAllDay => 'Todo el día';

  @override
  String get extCalSheetTitle => 'Cita de una suscripción';

  @override
  String get extCalSettingsRefreshHint =>
      'El servidor consulta cada calendario aproximadamente una vez por hora.';

  @override
  String get extCalActive => 'Activo';

  @override
  String get extCalUrlLoading => 'Cargando la dirección';

  @override
  String get shoppingNavLabel => 'Compra';

  @override
  String get scanHint => 'Apunta la cámara al código QR del otro dispositivo.';

  @override
  String get scanCameraDenied =>
      'WuselWall no tiene acceso a la cámara y no puede escanear el código. Permite el acceso en los ajustes del sistema o escribe el código.';

  @override
  String get scanCameraUnavailable =>
      'Este dispositivo no tiene una cámara que WuselWall pueda usar. Escribe el código.';

  @override
  String get scanWebUnsupported =>
      'Este navegador no puede escanear códigos QR. Escribe el código.';

  @override
  String get scanTypeCode => 'Escribir el código';

  @override
  String get feedSubTitle => 'Incluir calendarios externos';

  @override
  String get feedSubHelp =>
      'Los eventos de calendarios importados, como los de un club o la recogida de basura, también aparecerán en esta suscripción.';

  @override
  String get feedSubSummary => 'Calendarios externos';

  @override
  String get boardAllEvents => 'Todos los eventos';

  @override
  String boardMemberDay(String name, String date) {
    return '$name, $date';
  }

  @override
  String get reminderChannelName => 'Recordatorios';

  @override
  String get reminderStartLabel => 'Activar recordatorios';

  @override
  String reminderMorningEventsAndTasks(int events, int tasks) {
    String _temp0 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: '$events citas',
      one: '1 cita',
    );
    String _temp1 = intl.Intl.pluralLogic(
      tasks,
      locale: localeName,
      other: '$tasks tareas',
      one: '1 tarea',
    );
    return 'Hoy: $_temp0, $_temp1';
  }

  @override
  String reminderMorningEventsOnly(int events) {
    String _temp0 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: '$events citas',
      one: '1 cita',
    );
    return 'Hoy: $_temp0';
  }

  @override
  String reminderMorningTasksOnly(int tasks) {
    String _temp0 = intl.Intl.pluralLogic(
      tasks,
      locale: localeName,
      other: '$tasks tareas',
      one: '1 tarea',
    );
    return 'Hoy: $_temp0';
  }

  @override
  String reminderMorningApprovals(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aprobaciones pendientes',
      one: '1 aprobación pendiente',
    );
    return '$_temp0';
  }

  @override
  String get reminderMorningNoEvents => 'No hay nada previsto para hoy.';

  @override
  String reminderMorningFirst(String time, String title) {
    return 'Primero, a las $time: $title';
  }

  @override
  String reminderMorningAllDay(String title) {
    return 'Todo el día: $title';
  }

  @override
  String reminderEventBody(String time) {
    return 'Empieza a las $time';
  }

  @override
  String get reminderSettingsTitle => 'Recordatorios';

  @override
  String get reminderSettingsSubtitle => 'En este teléfono';

  @override
  String get reminderSettingsSection => 'Qué quieres que te recordemos';

  @override
  String get reminderStatusOn =>
      'Los recordatorios están activados en este teléfono.';

  @override
  String get reminderStatusOff =>
      'Los recordatorios están desactivados en este teléfono.';

  @override
  String get reminderStatusUnavailable =>
      'Este dispositivo no puede mostrar recordatorios.';

  @override
  String get reminderEnableAction => 'Activar recordatorios';

  @override
  String get reminderDeniedNote =>
      'Sin permiso no hay recordatorios. Puedes cambiar el permiso en los ajustes del sistema.';

  @override
  String get reminderLocalNote =>
      'Los recordatorios se crean en este teléfono. No se envía nada a ningún servidor ni a otras personas.';

  @override
  String get reminderOnlyPersonal =>
      'Los recordatorios solo están disponibles en el dispositivo personal de un miembro.';

  @override
  String get pairFrontDoorAction =>
      'Conectar una tableta familiar o pantalla de pared';

  @override
  String get pairTitle => 'Conectar este dispositivo';

  @override
  String get pairScanHint =>
      'Abre WuselWall en tu teléfono y escanea este código.';

  @override
  String get pairCodeHint =>
      'O, en el teléfono: Ajustes → Dispositivos → Conectar un dispositivo, e introduce el código.';

  @override
  String get pairQrLabel => 'Código QR para conectar este dispositivo';

  @override
  String get pairWaiting => 'Esperando aprobación…';

  @override
  String pairConnected(String household) {
    return 'Conectado a $household';
  }

  @override
  String get pairOldCodeLink =>
      'Tengo un código de un teléfono (versión anterior)';

  @override
  String get pairConnectAction => 'Conectar un dispositivo';

  @override
  String get pairOldCodeAction => 'Crear un código para un dispositivo antiguo';

  @override
  String get pairEntryBody =>
      'Escanea el código que aparece en el nuevo dispositivo o escríbelo.';

  @override
  String get pairCodeField => 'Código del nuevo dispositivo';

  @override
  String get pairNext => 'Siguiente';

  @override
  String get pairReviewBody =>
      'Este es el código del dispositivo que se va a conectar.';

  @override
  String get pairConfirmHint =>
      'Confirma solo si tienes este dispositivo delante.';

  @override
  String get pairKindLabel => '¿Qué tipo de dispositivo es?';

  @override
  String get pairKindWall => 'Pantalla de pared';

  @override
  String get pairKindKid => 'Tableta infantil';

  @override
  String get pairKindFamily => 'Tableta compartida';

  @override
  String get pairKindChild => 'Teléfono de un niño o niña';

  @override
  String get pairChildLabel => '¿De qué niño o niña?';

  @override
  String get pairNameLabel => 'Nombre del dispositivo';

  @override
  String get pairDefaultWall => 'Pantalla de pared';

  @override
  String get pairDefaultKid => 'Tableta infantil';

  @override
  String get pairDefaultFamily => 'Tableta';

  @override
  String pairDefaultChild(String name) {
    return 'Teléfono de $name';
  }

  @override
  String get pairApproveAction => 'Conectar';

  @override
  String get pairApproved => 'Dispositivo conectado';

  @override
  String get pairOnlyOnPersonal => 'Esto solo funciona en tu propio teléfono.';

  @override
  String get pairPinTitle => 'Establecer el PIN de responsable';

  @override
  String get pairPinBody =>
      'El PIN confirma los cambios en dispositivos compartidos. Solo tienes que establecerlo una vez.';

  @override
  String get pairPinConfirm => 'Vuelve a introducir el PIN';

  @override
  String get pairPinMismatch => 'Los PIN no coinciden. Inténtalo de nuevo.';

  @override
  String get firstRunKioskTitle => 'Configurar la pantalla de pared';

  @override
  String get firstRunKioskBody =>
      'Tres pasos, una sola vez en este dispositivo. Después mostrará la semana.';

  @override
  String get firstRunPinTitle => 'Mantener la aplicación abierta';

  @override
  String get firstRunPinIos =>
      'Ajustes → Accesibilidad → Acceso guiado: actívalo. Abre WuselWall y pulsa el botón superior tres veces seguidas.';

  @override
  String get firstRunPinAndroid =>
      'Ajustes → Seguridad → Fijar aplicación (en algunos dispositivos, «Fijar pantalla»). Abre WuselWall, abre las aplicaciones recientes y toca la chincheta.';

  @override
  String get firstRunAwakeTitle => 'Mantener la pantalla encendida';

  @override
  String get firstRunAwakeIos =>
      'Ajustes → Pantalla y brillo → Bloqueo automático → Nunca.';

  @override
  String get firstRunAwakeAndroid =>
      'Ajustes → Pantalla → Tiempo de espera de la pantalla: elige el máximo.';

  @override
  String get firstRunPowerTitle => 'Dejar conectado a la corriente';

  @override
  String get firstRunPowerBody =>
      'Déjalo conectado a la corriente para que vuelva a estar listo tras un corte de luz.';

  @override
  String get firstRunDone => 'Listo';

  @override
  String get firstRunKidTitle => 'Te damos la bienvenida';

  @override
  String get firstRunKidBody => 'Toca tu imagen y WuselWall sabrá quién eres.';

  @override
  String get firstRunKidStart => 'Vamos allá';

  @override
  String get householdNewTitle => 'Nueva familia';

  @override
  String get householdNewFamilyName => 'Nombre de la familia';

  @override
  String get householdNewYourName => 'Tu nombre';

  @override
  String get householdNewColour => 'Tu color';

  @override
  String householdNewColourOption(String number) {
    return 'Color $number';
  }

  @override
  String householdNewFamilyPrefill(String name) {
    return 'Familia $name';
  }

  @override
  String householdNewDefaults(String timezone, String language) {
    return 'Zona horaria $timezone · Idioma $language: según tu dispositivo';
  }

  @override
  String get householdLanguageDe => 'Alemán';

  @override
  String get householdLanguageEn => 'Inglés';

  @override
  String get householdLanguageFr => 'Francés';

  @override
  String get householdLanguageEs => 'Español';

  @override
  String get householdNewFounderCode => 'Código de configuración';

  @override
  String get householdNewFounderHelp =>
      'Usa el código de configuración que apareció al instalar el servidor o pídeselo a quien lo administra. No es el código del correo de inicio de sesión.';

  @override
  String get householdNewCodeSaved =>
      'Se ha guardado el código de tu enlace de configuración. No necesitas volver a introducirlo.';

  @override
  String get householdSeedExamples =>
      'Empezar con ejemplos: 5 tareas y 3 recompensas';

  @override
  String get householdNewCreate => 'Crear familia';

  @override
  String get householdNewInvited => 'Tengo una invitación';

  @override
  String get householdInvitedNote =>
      'Las invitaciones llegarán con la próxima actualización.';

  @override
  String get householdNewSignOut => 'Cerrar sesión';

  @override
  String get householdNewErrNoCode =>
      'Este servidor necesita un código de configuración para crear una familia. Usa el código de la instalación del servidor, no el del correo.';

  @override
  String get householdNewErrCodeWrong =>
      'El código de configuración no es válido o ya se ha usado. Pide un nuevo enlace o código de configuración a quien administra vuestro servidor.';

  @override
  String get householdNewErrRateLimited =>
      'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';

  @override
  String get householdNewStalled =>
      'Esto está tardando más de lo habitual. Espera o cierra sesión y vuelve a iniciarla. No crees la familia por segunda vez.';

  @override
  String get setupPrivacy => 'Política de privacidad';

  @override
  String get householdMembersTitle => '¿Quién más forma parte de tu familia?';

  @override
  String householdMembersYou(String name) {
    return '$name (tú)';
  }

  @override
  String get householdKindChild => 'Niño o niña';

  @override
  String get householdKindAdult => 'Adulto';

  @override
  String get householdMembersName => 'Nombre';

  @override
  String get householdMembersAdd => 'Añadir una persona';

  @override
  String get householdMembersRemove => 'Quitar';

  @override
  String get householdMembersDone => 'Listo';

  @override
  String get householdMembersSkip => 'Omitir';

  @override
  String get householdMembersHelp =>
      'Puedes invitar a los adultos más adelante.';

  @override
  String householdDeviceLabel(String owner, String device) {
    return '$owner $device';
  }

  @override
  String get householdDeviceIphone => 'iPhone';

  @override
  String get householdDeviceAndroid => 'teléfono Android';

  @override
  String get householdDeviceBrowser => 'navegador';

  @override
  String get householdDeviceComputer => 'ordenador';

  @override
  String get emailContinue => 'Continuar';

  @override
  String get emailHavePassword => 'Tengo una contraseña';

  @override
  String get emailWrongCredentials =>
      'El correo o la contraseña son incorrectos.';

  @override
  String get emailUseCodeInstead => 'Usar un código por correo';

  @override
  String get emailOffline =>
      'Sin conexión: necesitas conexión para iniciar sesión por correo.';

  @override
  String get emailRequired => 'Introduce tu dirección de correo electrónico.';

  @override
  String get emailInvalid =>
      'Introduce una dirección de correo electrónico válida.';

  @override
  String get passwordRequired => 'Introduce tu contraseña.';

  @override
  String get emailSendingCode => 'Enviando código…';

  @override
  String get signInProgress => 'Iniciando sesión…';

  @override
  String get emailCodeTitle => 'Código del correo';

  @override
  String emailCodeSent(String email) {
    return 'Hemos enviado un código de 6 dígitos a $email. Es válido durante 10 minutos.';
  }

  @override
  String get emailCodeFieldLabel => 'Código de seis dígitos';

  @override
  String get emailCodeWrong =>
      'El código es incorrecto o ha caducado. Inténtalo de nuevo o pide otro.';

  @override
  String emailCodeResendIn(int seconds) {
    return '¿No has recibido el código? Reenviar (en $seconds s)';
  }

  @override
  String get emailCodeResend => '¿No has recibido el código? Reenviar';

  @override
  String get emailCodeSpam => 'Revisa la carpeta de correo no deseado.';

  @override
  String get emailCodeResent => 'Hay un nuevo código en camino.';

  @override
  String get emailCodeOtherMethod => 'Elegir otro método';

  @override
  String get emailCodeOtherAddress => 'Otra dirección de correo';

  @override
  String get signInMethodTitle =>
      '¿Cómo quieres iniciar sesión la próxima vez?';

  @override
  String get signInMethodCode =>
      'Con un código por correo: sin tener que recordar nada';

  @override
  String get signInMethodPassword => 'Con contraseña';

  @override
  String get passwordStrengthShort => 'Aún demasiado corta';

  @override
  String get passwordStrengthWeak => 'Débil';

  @override
  String get passwordStrengthFair => 'Media';

  @override
  String get passwordStrengthStrong => 'Segura';

  @override
  String get settingsPasswordTitle => 'Contraseña';

  @override
  String get settingsPasswordSet =>
      'Establecida. También puedes iniciar sesión con correo y contraseña.';

  @override
  String get settingsPasswordNotSet =>
      'Sin establecer. Puedes seguir iniciando sesión con un código por correo.';

  @override
  String get passwordSetAction => 'Establecer contraseña';

  @override
  String get passwordChangeAction => 'Cambiar contraseña';

  @override
  String get passwordSaved => 'Tu contraseña se ha guardado.';

  @override
  String get passwordDialogBody =>
      'Al menos 10 caracteres. El código por correo siempre seguirá disponible.';

  @override
  String signInMethodEmailSubtitle(String email) {
    return '$email: siempre disponible';
  }

  @override
  String get signInMethodAlwaysAvailable => 'Siempre disponible';

  @override
  String get leaveLeaveTile => 'Salir de la familia';

  @override
  String get leaveLeaveExplain =>
      'Tu cuenta sale de la familia. Se cierra la sesión en tus dispositivos. Las entradas se quedan con la familia; después puedes crear otra familia o unirte a una.';

  @override
  String get leaveLeaveBlocked =>
      'Primero invita a otro adulto o elimina la familia.';

  @override
  String get leaveLeaveDialogTitle => '¿Salir de la familia?';

  @override
  String get leaveLeaveDialogBody =>
      'Perderás el acceso a esta familia. La familia seguirá existiendo y los demás seguirán en ella.';

  @override
  String get leaveLeaveConfirm => 'Salir';

  @override
  String get leaveCancel => 'Cancelar';

  @override
  String get leaveDeleteTile => 'Eliminar familia';

  @override
  String get leaveDeleteExplain =>
      'La familia y todos sus datos se eliminan de inmediato y de forma permanente. Se cierra la sesión en todos los dispositivos. Esta acción no se puede deshacer.';

  @override
  String get leaveDeleteDialogTitle => '¿Eliminar la familia?';

  @override
  String get leaveDeleteDialogBody =>
      'Se cierra la sesión en todos los dispositivos y se elimina la familia de forma permanente con todos sus datos.';

  @override
  String leaveDeleteNameLabel(String name) {
    return 'Escribe «$name» para confirmar';
  }

  @override
  String get leaveDeleteNext => 'Siguiente';

  @override
  String get leaveDeleteWordTitle => '¿Eliminar para siempre?';

  @override
  String get leaveDeleteWordBody =>
      'La familia y todos sus datos se eliminan de inmediato y de forma permanente. Nadie puede recuperarlos, ni siquiera un tutor. Exporta primero los datos si quieres conservarlos.';

  @override
  String get leaveDeleteWord => 'ELIMINAR';

  @override
  String leaveDeleteWordLabel(String word) {
    return 'Escribe $word para eliminar la familia para siempre';
  }

  @override
  String get leaveDeleteConfirm => 'Eliminar familia';

  @override
  String leaveDeletedTitle(String family, String date) {
    return '$family se eliminará definitivamente el $date';
  }

  @override
  String get leaveDeletedBodyGuardian =>
      'Puedes restaurar la familia. Todos los datos siguen ahí. Este teléfono volverá a ser el teléfono de la familia; los otros dispositivos tendrán que iniciar sesión de nuevo.';

  @override
  String get leaveDeletedBodyMember =>
      'Solo un responsable puede restaurar la familia. También puedes empezar de nuevo; en ese caso, tu cuenta saldrá de esta familia.';

  @override
  String get leaveRestore => 'Restaurar';

  @override
  String get leaveStartAfresh => 'Empezar de nuevo';

  @override
  String get leaveStartAfreshHint =>
      'Tu cuenta sale de la familia eliminada y creas una nueva.';

  @override
  String get leaveErrConfirmName => 'El nombre no coincide.';

  @override
  String get leaveErrHouseholdDeleted => 'Esta familia se ha eliminado.';

  @override
  String get leaveErrRestoreExpired => 'Esta familia ya no se puede restaurar.';

  @override
  String get leaveErrNotDeleted => 'Esta familia no está eliminada.';

  @override
  String get leaveErrAdultRequired =>
      'Solo los adultos tienen su propia cuenta.';

  @override
  String get leaveErrAlreadyInHousehold =>
      'Esta cuenta ya pertenece a una familia.';

  @override
  String get inviteDoorAction => 'Tengo un código de invitación';

  @override
  String get inviteCodeTitle => 'Invitación';

  @override
  String get inviteCodeBody =>
      'Introduce el código o pega el enlace que te han enviado.';

  @override
  String get inviteCodeLabel => 'Código o enlace';

  @override
  String get inviteCheckAction => 'Comprobar invitación';

  @override
  String get inviteCodeInvalidFormat =>
      'Esto no es un código de invitación ni un enlace de WuselWall.';

  @override
  String get inviteNoLonger =>
      'Esta invitación ya no es válida. Pide otra a la persona que te invitó.';

  @override
  String get inviteRateLimited =>
      'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';

  @override
  String inviteBanner(String inviter, String household) {
    return '$inviter te ha invitado a $household';
  }

  @override
  String inviteBannerNoInviter(String household) {
    return 'Tienes una invitación a $household';
  }

  @override
  String get inviteRoleLineGuardian =>
      'Como responsable, puedes verlo todo y aprobar recompensas.';

  @override
  String get inviteRoleLineMember =>
      'Como miembro, completas tareas, pero no apruebas recompensas.';

  @override
  String get inviteContinue => 'Continuar al inicio de sesión';

  @override
  String get inviteJoin => 'Unirme';

  @override
  String get inviteNewFamilyInstead => 'Crear mi propia familia';

  @override
  String inviteJoinTitle(String name, String household) {
    return 'Eres $name en $household';
  }

  @override
  String get inviteJoinHint =>
      'Tu nombre y color, tal como los ve la familia. Puedes cambiarlos después en Ajustes.';

  @override
  String get inviteJoinDecline => 'No unirme';

  @override
  String inviteAlreadyIn(String household) {
    return 'Ya formas parte de $household.';
  }

  @override
  String inviteAlreadyInTitle(String household) {
    return 'Ya formas parte de $household';
  }

  @override
  String inviteAlreadyInSame(String household) {
    return 'Esta invitación es para $household, y ya formas parte de ella. No tienes que hacer nada más.';
  }

  @override
  String get inviteAlreadyInLeaveHint =>
      'Una cuenta pertenece a una sola familia. Para unirte, sal primero de tu familia actual; después la invitación sigue.';

  @override
  String get inviteAlreadyInLeaveHintUnknown =>
      'Una cuenta pertenece a una sola familia. Para unirte a otra, sal primero de tu familia actual y luego abre de nuevo la invitación.';

  @override
  String get inviteAlreadyInDevice =>
      'Este dispositivo ya pertenece a una familia. Abre la invitación en el móvil de la persona invitada.';

  @override
  String get invitePartnerPickTitle => '¿A quién quieres invitar?';

  @override
  String get invitePartnerExisting =>
      'Ya está en la familia, todavía sin cuenta';

  @override
  String get invitePartnerSomeoneElse => 'Otra persona';

  @override
  String get invitePartnerSomeoneElseHint =>
      'Añade un nuevo adulto a la familia';

  @override
  String get inviteNothingKept => 'Ya no hay ninguna invitación para unirse.';

  @override
  String inviteResultTitle(String name) {
    return 'Invitación para $name';
  }

  @override
  String get inviteResultHint =>
      'La persona introduce el código en WuselWall o escanea el código QR.';

  @override
  String inviteValidUntil(String date) {
    return 'Válida hasta el $date';
  }

  @override
  String get inviteQrLabel => 'Código QR de la invitación';

  @override
  String get inviteShare => 'Compartir';

  @override
  String get inviteDone => 'Listo';

  @override
  String inviteShareMessage(
    String household,
    String link,
    String code,
    String server,
  ) {
    return 'Únete a $household en WuselWall: $link, o introduce el código $code en la aplicación, en el servidor $server.';
  }

  @override
  String get inviteAdultTitle => 'Invitar a un adulto';

  @override
  String get inviteAdultName => 'Nombre';

  @override
  String get inviteAdultRole => 'Rol';

  @override
  String get inviteRoleGuardian => 'Responsable';

  @override
  String get inviteRoleMember => 'Miembro';

  @override
  String get inviteRoleGuardianHelp =>
      'Puede verlo todo y aprobar recompensas.';

  @override
  String get inviteRoleMemberHelp =>
      'Completa tareas, pero no aprueba recompensas. Por ejemplo, para una persona que cuida de los niños o para los abuelos.';

  @override
  String get inviteAdultEmail => 'Correo electrónico (opcional)';

  @override
  String get inviteAdultEmailHelp =>
      'Con esta dirección, la persona encontrará automáticamente la invitación al iniciar sesión.';

  @override
  String get inviteEmailInvalid =>
      'Esto no parece una dirección de correo electrónico.';

  @override
  String get inviteCreate => 'Crear invitación';

  @override
  String get inviteInviteAction => 'Invitar';

  @override
  String inviteOpenUntil(String date) {
    return 'Invitación pendiente · hasta el $date';
  }

  @override
  String get inviteShareAgain => 'Compartir de nuevo';

  @override
  String get inviteWithdraw => 'Retirar';

  @override
  String get inviteWithdrawn => 'Invitación retirada.';

  @override
  String get inviteScanTitle => 'Escanear invitación';

  @override
  String get accountDeleteTile => 'Eliminar cuenta';

  @override
  String get accountDeleteExplain =>
      'Se eliminan tu cuenta y sus métodos de inicio de sesión, y se cierra tu sesión en todas partes. Tu perfil se queda en la familia con su historial.';

  @override
  String get accountDeleteBlocked =>
      'Eres la última persona responsable con cuenta de esta familia. Primero invita a otro adulto o elimina la familia.';

  @override
  String get accountDeleteDialogTitle => '¿Eliminar la cuenta?';

  @override
  String get accountDeleteDialogBody =>
      'Esto no se puede deshacer. Se eliminará tu acceso, pero tu perfil seguirá en la familia.';

  @override
  String get accountDeleteConfirm => 'Eliminar cuenta';

  @override
  String get accountDeleteRefused =>
      'No se ha podido eliminar la cuenta. Inténtalo más tarde.';

  @override
  String get accountDeleteReauthTitle => 'Confirma que eres tú';

  @override
  String accountDeleteReauthBody(String email) {
    return 'Para eliminar una cuenta necesitas iniciar sesión de nuevo. Te enviaremos un código a $email.';
  }

  @override
  String get accountDeleteReauthSend => 'Enviar código';

  @override
  String get accountDeleteReauthCodeLabel => 'Código del correo';

  @override
  String get accountDeleteReauthConfirm => 'Confirmar';

  @override
  String get accountDeleteReauthSignInAgain =>
      'Primero vuelve a iniciar sesión y después podrás eliminar la cuenta.';

  @override
  String get mfaResetAction => 'Restablecer la verificación en dos pasos';

  @override
  String get mfaResetConfirmTitle =>
      '¿Restablecer la verificación en dos pasos?';

  @override
  String mfaResetConfirmBody(String name) {
    return 'Después, $name podrá iniciar sesión sin un segundo factor y configurarlo de nuevo.';
  }

  @override
  String get mfaResetConfirm => 'Restablecer';

  @override
  String mfaResetDone(String name) {
    return 'Se ha restablecido el segundo factor de $name.';
  }

  @override
  String get serverTitle => '¿Qué servidor quieres usar?';

  @override
  String get serverLead =>
      'WuselWall guarda los datos de tu familia en vuestro propio servidor. Introduce su dirección o escanea su código QR. ¿Tienes una invitación? Pega el enlace o el código junto con el servidor, como K7QM3XRP@api.example.org.';

  @override
  String get serverAddressLabel => 'Dirección del servidor';

  @override
  String get serverAddressHint => 'p. ej., api.example.org';

  @override
  String get serverConnect => 'Conectar';

  @override
  String get serverScan => 'Escanear código QR';

  @override
  String get serverScanTitle => 'Escanear el código QR del servidor';

  @override
  String get serverDemo => 'Probar sin servidor';

  @override
  String get serverDemoHint =>
      'Con una familia de ejemplo. Nada sale de este dispositivo.';

  @override
  String get serverHelp =>
      '¿Aún no tenéis servidor? La guía de wuselwall.app/docs explica cómo configurarlo.';

  @override
  String get serverInvalid => 'Esto no es una dirección de servidor.';

  @override
  String get serverUnreachable =>
      'El servidor no responde. ¿La dirección es correcta y tienes conexión?';

  @override
  String get serverNotWuselwall =>
      'No hay ningún servidor WuselWall en esta dirección.';

  @override
  String get serverTooOld =>
      'Este servidor necesita una actualización. Pide a quien lo administra que actualice WuselWall.';

  @override
  String get serverAppTooOld =>
      'Este servidor necesita una versión más reciente de la aplicación. Actualiza WuselWall.';

  @override
  String get serverLinkWithoutServer =>
      'Este enlace no indica a qué servidor pertenece. Introduce arriba la dirección del servidor y después el código.';

  @override
  String inviteResultServer(String server) {
    return 'Servidor: $server';
  }

  @override
  String get linkOtherServerTitle => 'Este enlace pertenece a otro servidor';

  @override
  String linkSwitchBody(String host, String current) {
    return 'El enlace apunta a $host, pero esta aplicación está conectada a $current. ¿Cambiar a $host?';
  }

  @override
  String get linkSwitchAction => 'Cambiar de servidor';

  @override
  String linkOtherServerBody(String host, String current) {
    return 'El enlace apunta a $host, pero has iniciado sesión en $current. Primero cierra sesión (Ajustes → Cambiar de servidor) y después abre de nuevo el enlace.';
  }

  @override
  String get serverIncompatibleTitle =>
      'El servidor y la aplicación no son compatibles';

  @override
  String get serverChooseOther => 'Elegir otro servidor';

  @override
  String get demoBanner => 'Familia de ejemplo: no se guarda nada';

  @override
  String get demoExit => 'Salir';

  @override
  String get settingsServer => 'Servidor';

  @override
  String settingsServerBody(String address) {
    return 'Esta aplicación se conecta a $address. Escanea este código con la aplicación WuselWall en otro dispositivo para conectarlo al mismo servidor.';
  }

  @override
  String get settingsServerSwitch => 'Cambiar de servidor';

  @override
  String get settingsServerSwitchConfirm =>
      'Se cerrará la sesión de este dispositivo y se borrará todo lo que tenga guardado. Después podrás elegir otro servidor.';

  @override
  String get setupPhoneTitle => 'Continuar en tu teléfono';

  @override
  String get setupPhoneBody =>
      'Abre la aplicación WuselWall en tu teléfono, escanea el código para elegir este servidor e inicia sesión allí.';

  @override
  String get shortcutTitle => 'Apps y automatizaciones';

  @override
  String get shortcutIntro =>
      'Una clave permite que otra aplicación use WuselWall en nombre de una persona. Una clave de automatización, por ejemplo para un atajo de Siri en el iPhone o cualquier aplicación que pueda llamar a una dirección web, permite leer y añadir: añade artículos a la lista de la compra e indica qué hay hoy, qué hay para comer o quién tiene educación física mañana. No permite eliminar ni administrar nada.';

  @override
  String get shortcutEmpty => 'Aún no hay claves.';

  @override
  String get shortcutKioskNote =>
      'Las claves se crean en un teléfono personal, no en la pantalla de pared.';

  @override
  String get shortcutNew => 'Nueva clave';

  @override
  String get shortcutLabelField => 'Nombre';

  @override
  String get shortcutLabelHint => 'p. ej., iPhone';

  @override
  String get shortcutForWhom => '¿Para quién?';

  @override
  String get shortcutForWhomHelp =>
      'El atajo actúa como esta persona: marca sus tareas y dice sus puntos.';

  @override
  String get shortcutCreate => 'Crear clave';

  @override
  String shortcutKeyTitle(String name) {
    return 'Clave para $name';
  }

  @override
  String shortcutKeyOnce(String name) {
    return 'Esta clave solo se muestra ahora. Quien la tenga puede leer y añadir en nombre de $name, así que trátala como una contraseña. En la aplicación Atajos de Apple se sincroniza a través de iCloud.';
  }

  @override
  String get shortcutCopyKey => 'Copiar clave';

  @override
  String get shortcutAddressLabel => 'Dirección';

  @override
  String get shortcutCopyAddress => 'Copiar dirección';

  @override
  String get shortcutCopied => 'Copiado.';

  @override
  String get shortcutHowTitle => 'Cómo funciona';

  @override
  String get shortcutHowSteps =>
      'Todas las aplicaciones envían la misma solicitud. Con Atajos de Apple, crea un atajo con la acción «Obtener contenido de URL»: la dirección terminada en /today y una cabecera «Authorization» con «Bearer», un espacio y la clave. Después añade «Mostrar resultado» o «Leer texto». La guía de wuselwall.app/docs/en/settings/shortcuts muestra cada atajo.';

  @override
  String shortcutLastUsed(String when) {
    return 'Último uso: $when';
  }

  @override
  String get shortcutNeverUsed => 'Nunca usada';

  @override
  String shortcutUseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count consultas',
      one: '1 consulta',
    );
    return '$_temp0';
  }

  @override
  String get shortcutRevoked => 'Revocada';

  @override
  String get shortcutRevokeAction => 'Revocar';

  @override
  String shortcutRevokeConfirm(String label) {
    return '¿Revocar «$label»? El atajo dejará de funcionar de inmediato.';
  }

  @override
  String get shortcutErrLabel =>
      'Introduce un nombre de 60 caracteres como máximo.';

  @override
  String get shortcutErrLimit =>
      'Esta persona ya tiene diez claves. Primero revoca una.';

  @override
  String get shortcutSectionAutomations => 'Automatizaciones';

  @override
  String get shortcutSectionAssistants => 'Asistentes de IA';

  @override
  String get shortcutKindShortcut => 'Automatización';

  @override
  String get shortcutKindAssistant => 'Asistente de IA';

  @override
  String get shortcutKindShortcutHelp =>
      'Para Siri y Atajos de Apple, o cualquier aplicación que pueda llamar a una dirección web: permite leer y añadir, por ejemplo a la lista de la compra.';

  @override
  String get shortcutKindAssistantHelp =>
      'Para un asistente de IA compatible con MCP, como Claude: solo permite leer y solo está disponible para adultos.';

  @override
  String get shortcutAssistantLabelHint => 'p. ej., Claude en el portátil';

  @override
  String shortcutAssistantKeyOnce(String name) {
    return 'Esta clave solo se muestra ahora. Con ella, un asistente lee como $name toda la semana de la familia: citas, quién está fuera, horarios escolares, tareas, comidas y lista de la compra. Lo que lee se envía al proveedor del asistente. Trata la clave como una contraseña.';
  }

  @override
  String get shortcutAssistantHowSteps =>
      'Añade la dirección como servidor MCP en tu asistente y envía la clave en la cabecera «Authorization» con «Bearer », un espacio y la clave. La guía de wuselwall.app/docs/en/settings/shortcuts explica cómo hacerlo en algunos asistentes.';

  @override
  String get shortcutErrAdultOnly =>
      'Solo los adultos pueden tener una clave para un asistente.';

  @override
  String get reminderPackTitle => 'Preparar la mochila para mañana';

  @override
  String reminderPackChild(String name, String items) {
    return '$name: $items';
  }

  @override
  String get settingNotifyPackingTitle =>
      'Recordatorio de mochila la noche anterior';

  @override
  String get settingNotifyPackingHelp =>
      'A esta hora, tu teléfono te indica qué hay que llevar mañana en la mochila según los horarios, como la ropa de Educación Física. Solo avisa si hay algo que preparar.';

  @override
  String get appearanceTitle => 'Apariencia';

  @override
  String get appearanceSystem => 'Automático';

  @override
  String get appearanceSystemHelp =>
      'Claro u oscuro, según el ajuste de este dispositivo';

  @override
  String get appearanceLight => 'Claro';

  @override
  String get appearanceDark => 'Oscuro';

  @override
  String get appearanceNightNote =>
      'Por la noche, la pantalla de pared siempre muestra su vista nocturna.';

  @override
  String get languageTitle => 'Idioma';

  @override
  String get languageSystem => 'Automático';

  @override
  String languageSystemCurrent(String name) {
    return 'Automático: $name';
  }

  @override
  String get languageSystemHelp =>
      'El idioma de este dispositivo; alemán si la app no lo tiene';

  @override
  String get languageNameDe => 'Deutsch';

  @override
  String get languageNameEn => 'English';

  @override
  String get languageNameFr => 'Français';

  @override
  String get languageNameEs => 'Español';

  @override
  String get settingsViewLabel => 'Qué ajustes mostrar';

  @override
  String get settingsViewAdvanced => 'Avanzados';

  @override
  String get settingsViewMoreHint =>
      'Hay más ajustes en Avanzados. Los ajustes ocultos siguen activos.';

  @override
  String get settingsViewShowAll => 'Mostrar todos los ajustes';

  @override
  String get schoolTimetableNeedsTerm =>
      'La semana mostrada aún no pertenece a ningún periodo. Añade el periodo al que pertenece y después introduce las clases.';

  @override
  String get schoolTermContinue => 'Guardar período y continuar';

  @override
  String get schoolSetupFirstHint =>
      'Se proponen horas de clase (desde las 8:00, 45 minutos) y una lista de asignaturas. Ambas se pueden ajustar después.';

  @override
  String get schoolSetupCreate => 'Crear colegio';

  @override
  String get schoolNextSteps => 'Siguientes pasos';

  @override
  String schoolNextStepEnter(String name) {
    return 'Introducir el horario de $name';
  }

  @override
  String get schoolTermProposedHint =>
      'Propuesto: el curso escolar actual. Ajusta el nombre y las fechas si tu colegio lo cuenta de otra forma.';

  @override
  String schoolYearName(String from, String to) {
    return 'Curso $from/$to';
  }

  @override
  String schoolCreateSubject(String name) {
    return 'Crear la asignatura «$name»';
  }

  @override
  String get schoolImportAction => 'Importar…';

  @override
  String get schoolImportFromText => 'Pegar como texto';

  @override
  String get schoolImportFromPhoto => 'Escanear una foto';

  @override
  String get schoolImportTitle => 'Importar un horario';

  @override
  String schoolImportProposedBy(String assistant) {
    return 'Propuesta de $assistant';
  }

  @override
  String schoolImportLessons(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clases',
      one: '1 clase',
    );
    return '$_temp0';
  }

  @override
  String schoolImportTermNew(String name) {
    return 'Periodo: $name (se creará)';
  }

  @override
  String schoolImportTermExisting(String name) {
    return 'Periodo: $name';
  }

  @override
  String schoolImportReplaces(String name, int count) {
    return 'Sustituye el horario existente de $name ($count clases).';
  }

  @override
  String get schoolImportNewSubjects => 'Asignaturas nuevas';

  @override
  String get schoolImportCreateSubjects => 'Crear las asignaturas nuevas';

  @override
  String get schoolImportSkipNewSubjects =>
      'Las clases con asignaturas nuevas se omiten.';

  @override
  String get schoolImportCreateNew => 'Crear nueva';

  @override
  String get schoolImportMergeHint =>
      '¿Ya existe la asignatura? Elígela y WuselWall recordará la palabra de la hoja.';

  @override
  String schoolImportWarnUnmatchedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count clases no coinciden con ninguna hora de clase y se omiten.',
      one: '1 clase no coincide con ninguna hora de clase y se omite.',
    );
    return '$_temp0';
  }

  @override
  String schoolImportWarnPeriodsExtended(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Las horas de clase reciben $count clases más.',
      one: 'Las horas de clase reciben 1 clase más.',
    );
    return '$_temp0';
  }

  @override
  String get schoolImportWarnPeriodsDiffer =>
      'Las horas de la hoja difieren de las del colegio; se mantienen las del colegio.';

  @override
  String schoolImportWarnSchoolDiffers(String name) {
    return 'La hoja indica otro colegio: $name.';
  }

  @override
  String get schoolImportApply => 'Aplicar';

  @override
  String get schoolImportDiscard => 'Descartar';

  @override
  String get schoolImportApplied => 'Horario aplicado.';

  @override
  String get schoolImportDiscarded => 'Propuesta descartada.';

  @override
  String get schoolImportNoChild => 'Añade primero a un niño en Miembros.';

  @override
  String get schoolImportPasteTitle => 'Importar desde texto';

  @override
  String get schoolImportPasteIntro =>
      'Pega un horario en JSON con el formato de WuselWall. Verás una vista previa antes de guardar.';

  @override
  String get schoolImportCopyPrompt =>
      'Copiar las instrucciones para el asistente';

  @override
  String get schoolImportPromptCopied => 'Instrucciones copiadas.';

  @override
  String get schoolImportPrompt =>
      'Lee el horario de la foto y devuélvelo como JSON en el formato siguiente, sin más texto. Días como lun, mar, mié, jue, vie; clases por número (1 = primera clase) o con hora de inicio y fin; asignaturas con la abreviatura de la hoja y, si la conoces, el nombre completo. Omite las casillas vacías. Para semanas A y B indica week: a o b. El comedor o la guardería van en care.';

  @override
  String get schoolImportPasteHint => 'Pega aquí el horario en JSON';

  @override
  String get schoolImportRead => 'Importar';

  @override
  String get schoolImportErrNotJson =>
      'Eso no es un horario en el formato de WuselWall. Pega el texto JSON completo.';

  @override
  String get schoolImportErrNoLessons => 'El texto no contiene clases.';

  @override
  String get schoolImportErrTooMany =>
      'Son más entradas de las que puede tener un horario.';

  @override
  String get schoolImportErrBadLesson =>
      'Una clase no tiene día, número o asignatura.';

  @override
  String schoolImportErrBadDay(String value) {
    return '«$value» no es un día de la semana.';
  }

  @override
  String schoolImportErrBadTime(String value) {
    return '«$value» no es una hora.';
  }

  @override
  String schoolProposalTitle(String assistant) {
    return 'Propuesta de $assistant';
  }

  @override
  String schoolProposalSummary(String name, int count) {
    return 'Horario de $name, $count clases';
  }

  @override
  String get schoolProposalReview => 'Revisar';

  @override
  String get schoolProposalUnreadable =>
      'Esta propuesta tiene un formato que esta versión de la app no puede leer.';

  @override
  String get schoolProposalErrInvalid =>
      'La propuesta tiene un formato no válido.';

  @override
  String get schoolProposalErrLimit =>
      'Ya hay cinco propuestas esperando. Revísalas o descártalas primero.';

  @override
  String get schoolProposalErrGone =>
      'Esta propuesta ya está resuelta o ha caducado.';

  @override
  String get schoolScanIntro =>
      'Tu servidor lee la foto o el PDF; nada sale de casa. Una foto recta y luminosa de toda la hoja da el mejor resultado; el PDF del colegio es el más exacto.';

  @override
  String get schoolScanCamera => 'Hacer una foto';

  @override
  String get schoolScanPick => 'Elegir una foto';

  @override
  String get schoolScanBusy => 'Leyendo la hoja…';

  @override
  String get schoolScanNotConfigured =>
      'Tu servidor no tiene reconocimiento de texto. La guía «Extras para el servidor» explica cómo añadirlo. Mientras tanto: importar desde texto.';

  @override
  String get schoolScanNothingFound =>
      'No se reconoció ningún horario en la foto. Prueba con una foto más recta y luminosa, o importa desde texto.';

  @override
  String get schoolScanTooLarge =>
      'La foto es demasiado grande (6 MB como máximo).';

  @override
  String get schoolScanFailed =>
      'El reconocimiento de texto del servidor no respondió. Inténtalo más tarde.';

  @override
  String schoolScanWarnUnplaced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count fragmentos de texto no encajaron en ninguna casilla. Compara la vista previa con la hoja.',
      one: '1 fragmento de texto no encajó en ninguna casilla. Compara la vista previa con la hoja.',
    );
    return '$_temp0';
  }

  @override
  String get savedMessage => 'Guardado.';

  @override
  String get settingsSectionThisDevice => 'Este dispositivo';

  @override
  String get settingsSectionConnect => 'Compartir y conexiones';

  @override
  String get settingsMembersHint =>
      'Toca a una persona para cambiar su nombre, color, imagen o rol. Arrastra el asa para cambiar el orden en la pared.';

  @override
  String get familyTitle => 'Familia';

  @override
  String get familySettingsSubtitle =>
      'Nombre, zona horaria, exportación de datos, eliminar';

  @override
  String get familyTimezone => 'Zona horaria';

  @override
  String get familyTimezoneHelp =>
      'La pared y los recordatorios siguen esta zona.';

  @override
  String get familyTimezoneSearch => 'Buscar zona horaria';

  @override
  String get familyLocale => 'Idioma en la pared';

  @override
  String get familyLocaleHelp =>
      'Los días festivos en la pantalla de pared se nombran en este idioma.';

  @override
  String get familyErrTimezone => 'Zona horaria desconocida.';

  @override
  String get memberColour => 'Color';

  @override
  String get memberAvatar => 'Imagen';

  @override
  String get memberAvatarInitial => 'Inicial';

  @override
  String get memberKind => 'Niño o adulto';

  @override
  String get memberRole => 'Rol';

  @override
  String get memberRoleHelp =>
      'Los adultos responsables ven todo y aprueban las recompensas. Los miembros marcan tareas.';

  @override
  String get memberReadOnlyHint =>
      'Solo los adultos responsables cambian a otras personas. Puedes cambiar tu propio nombre, color e imagen.';

  @override
  String get memberKioskReadOnly =>
      'En la pantalla de pared no se cambia a nadie. Cambia los nombres, los colores, las imágenes y los cumpleaños en la app de un móvil o una tableta.';

  @override
  String get memberInactive => 'Ya no está en la familia';

  @override
  String get memberInactiveBody =>
      'Fuera de la pared, de las filas de avatares y de las tareas nuevas. El historial y los puntos se conservan.';

  @override
  String get memberDeactivate => 'Ya no está en la familia';

  @override
  String memberDeactivateBody(String name) {
    return '$name desaparece de la pared, de las filas de avatares y de las tareas nuevas. El historial y los puntos se conservan, y puedes traer a la persona de vuelta aquí.';
  }

  @override
  String memberDeactivateConfirm(String name) {
    return '¿Quitar a $name de las pantallas de la familia? El historial y los puntos se conservan.';
  }

  @override
  String get memberReactivate => 'De vuelta';

  @override
  String memberHasAccountHint(String name) {
    return '$name tiene una cuenta y sale de la familia desde su propio móvil (Ajustes → Salir de la familia).';
  }

  @override
  String get memberReorderHandle => 'Cambiar el orden';

  @override
  String get memberErrKindAdult =>
      'Un adulto responsable, o alguien con cuenta, es adulto.';

  @override
  String get memberErrRoleChild =>
      'Un niño no puede ser adulto responsable. Primero conviértelo en adulto.';

  @override
  String get memberErrSelf =>
      'No puedes quitarte a ti mismo. Otro adulto responsable puede hacerlo.';

  @override
  String get memberErrHasAccount =>
      'Esta persona tiene una cuenta y sale de la familia desde su propio móvil.';

  @override
  String get deviceRename => 'Renombrar dispositivo';

  @override
  String deviceLastSeen(String ago) {
    return 'activo por última vez $ago';
  }

  @override
  String get deviceNeverSeen => 'aún no activo';

  @override
  String get shoppingEditList => 'Editar lista';

  @override
  String get shoppingListDefault => 'Lista predeterminada';

  @override
  String get shoppingListDefaultHelp =>
      'La pantalla de pared añade a la lista predeterminada.';

  @override
  String get shoppingCategories => 'Categorías';

  @override
  String get shoppingCategoriesHelp =>
      'En el orden de los pasillos. Arrastra el asa para reordenarlas.';

  @override
  String get shoppingCategoryAdd => 'Añadir categoría';

  @override
  String get shoppingCategoryRename => 'Renombrar categoría';

  @override
  String get shoppingCategoryName => 'Nombre de la categoría';

  @override
  String shoppingCategoryDeleteConfirm(String name) {
    return '¿Quitar «$name»? Sus productos se quedan en la lista sin categoría.';
  }

  @override
  String get shoppingListDelete => 'Eliminar lista';

  @override
  String shoppingListDeleteConfirm(String name) {
    return '¿Eliminar «$name»? Los productos pendientes pasan a la lista predeterminada; su historial y sus tarjetas desaparecen.';
  }

  @override
  String get shoppingErrListDefault =>
      'La lista predeterminada no se puede eliminar. Elige antes otra lista como predeterminada.';

  @override
  String get shoppingErrTileExists => 'Ya existe una tarjeta con este nombre.';

  @override
  String get shoppingTileAddEdit => 'Añadir y editar';

  @override
  String get shoppingTileRename => 'Renombrar tarjeta';

  @override
  String get shoppingTileForget => 'No sugerir más';

  @override
  String get shoppingTileForgetHelp =>
      'La tarjeta desaparece; el historial la conserva.';

  @override
  String shoppingTileForgetConfirm(String name) {
    return '¿Quitar la tarjeta «$name»? La próxima compra la traerá de vuelta.';
  }

  @override
  String get schoolScanFile => 'Elegir un archivo (PDF o imagen)';

  @override
  String get schoolImportPhotoUnavailable =>
      'Tu servidor todavía no lee fotos.';

  @override
  String get settingsVersions => 'Versiones';

  @override
  String settingsVersionsLine(String app, String server, String api) {
    return 'App $app · Servidor $server · API $api';
  }

  @override
  String get settingsVersionUnknown => 'desconocida';

  @override
  String get settingMemberWuselTitle => 'Wusel';

  @override
  String get settingMemberWuselHelp =>
      'Cuánto aparece Wusel para ti. Automático: animado para los niños, tranquilo para los adultos.';

  @override
  String get settingMemberWuselOutfitTitle => 'La ropa de Wusel';

  @override
  String get settingMemberWuselOutfitHelp =>
      'Lo que lleva Wusel cuando habla contigo. Toda la ropa está disponible desde el principio.';

  @override
  String get settingDeviceWuselTitle => 'Wusel en este dispositivo';

  @override
  String get settingDeviceWuselHelp =>
      'Lo animado que está Wusel aquí mientras no hay nadie elegido. El ajuste propio de una persona vale mientras está elegida.';

  @override
  String get settingDeviceSoundsTitle => 'Sonidos en este dispositivo';

  @override
  String get settingDeviceSoundsHelp =>
      'Automático: apagados en la pantalla de pared, encendidos en los demás. Nunca de noche.';

  @override
  String get settingDeviceSkyTitle => 'Cielo en la cabecera';

  @override
  String get settingDeviceSkyHelp =>
      'La cabecera muestra un cielo que cambia con la hora del día.';

  @override
  String get settingDevicePixelShiftTitle =>
      'Proteger la pantalla de quemaduras';

  @override
  String get settingDevicePixelShiftHelp =>
      'Mueve todo hasta 2 píxeles cada 10 minutos, para pantallas OLED siempre encendidas. Automático: activado en la pantalla de pared.';

  @override
  String get settingAmbienceSeasonTitle => 'Estaciones';

  @override
  String get settingAmbienceSeasonHelp =>
      'Flores, sol, hojas o copos de nieve en el cielo.';

  @override
  String get settingAmbienceBirthdaysTitle => 'Cumpleaños';

  @override
  String get settingAmbienceBirthdaysHelp =>
      'Banderines del color de la persona y un gorro de fiesta para Wusel en su cumpleaños.';

  @override
  String get settingAmbienceFerienTitle => 'Vacaciones escolares';

  @override
  String get settingAmbienceFerienHelp =>
      'Una cinta el primer y el último día de vacaciones.';

  @override
  String get settingAmbienceAdventTitle => 'Adviento';

  @override
  String get settingAmbienceAdventHelp =>
      'Velas en la cabecera, una más cada uno de los cuatro domingos antes de Navidad. Automático: según vuestra región.';

  @override
  String get settingAmbienceEasterWesternTitle => 'Pascua';

  @override
  String get settingAmbienceEasterWesternHelp =>
      'Huevos en las colinas, desde dos días antes hasta dos días después del Domingo de Pascua. Automático: según vuestra región.';

  @override
  String get settingAmbienceEasterOrthodoxTitle => 'Pascua ortodoxa';

  @override
  String get settingAmbienceEasterOrthodoxHelp =>
      'Los mismos huevos en la fecha ortodoxa, que se calcula cada año. Automático: según vuestra región.';

  @override
  String get settingAmbienceNewYearTitle => 'Nochevieja';

  @override
  String get settingAmbienceNewYearHelp =>
      'Pequeños fuegos artificiales en el cielo nocturno el 31 de diciembre y el 1 de enero.';

  @override
  String get settingRitualsCountdownDaysTitle => 'La cuenta atrás empieza';

  @override
  String get settingRitualsCountdownDaysHelp =>
      'Cuántos días antes de un cumpleaños, las vacaciones o una cita marcada aparece la cuenta atrás.';

  @override
  String get settingRitualsCountdownReturnTitle =>
      'Cuenta atrás hasta una vuelta';

  @override
  String get settingRitualsCountdownReturnHelp =>
      '«Vuelve en 2 noches» cuando un adulto viaja dos noches o más.';

  @override
  String get settingMealsWishesTitle => 'Comida deseada';

  @override
  String get settingMealsWishesHelp =>
      'Quién puede pedir una comida. La app nunca rechaza un deseo; espera hasta que se planifica.';

  @override
  String get settingMealsWishesPerWeekTitle => 'Deseos abiertos por persona';

  @override
  String get settingMealsWishesPerWeekHelp =>
      'Cuántos deseos puede tener cada persona esperando a la vez.';

  @override
  String get settingTableQuestionTitle => 'Pregunta en la mesa';

  @override
  String get settingTableQuestionHelp =>
      'Una pregunta para conversar, en la pantalla de pared y en la app durante la comida. Se responde en voz alta y no se guarda nada.';

  @override
  String get settingTableQuestionLunchTitle => 'Pregunta en la comida';

  @override
  String get settingTableQuestionLunchHelp =>
      'Cuándo aparece la pregunta al mediodía.';

  @override
  String get settingTableQuestionDinnerTitle => 'Pregunta en la cena';

  @override
  String get settingTableQuestionDinnerHelp =>
      'Cuándo aparece la pregunta en la cena.';

  @override
  String get settingTableQuestionDeckTitle => 'Preguntas para';

  @override
  String get settingTableQuestionDeckHelp =>
      'Todas las edades sirve desde los cinco años; niños mayores añade preguntas más profundas a partir de 8.';

  @override
  String get settingWeekReviewTitle => 'Nuestra semana';

  @override
  String get settingWeekReviewHelp =>
      'Cuándo aparece el repaso de la semana. Se queda hasta la mañana siguiente.';

  @override
  String get settingValueAuto => 'Automático';

  @override
  String get settingValueLively => 'Animado';

  @override
  String get settingValueQuiet => 'Tranquilo';

  @override
  String get settingValueOn => 'Activado';

  @override
  String get settingValueOff => 'Desactivado';

  @override
  String get settingValueChildren => 'Niños';

  @override
  String get settingValueEveryone => 'Todos';

  @override
  String get settingValueWarmMeal => 'Comida caliente';

  @override
  String get settingValueMainMeals => 'Comida y cena';

  @override
  String get settingValueAllAges => 'Todas las edades';

  @override
  String get settingValueOlderChildren => 'También niños mayores';

  @override
  String settingUnitDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días',
      one: '1 día',
    );
    return '$_temp0';
  }

  @override
  String get wuselOutfitNone => 'Nada';

  @override
  String get wuselOutfitParty => 'Gorro de fiesta';

  @override
  String get wuselOutfitCrown => 'Corona';

  @override
  String get wuselOutfitWizard => 'Sombrero de mago';

  @override
  String get wuselOutfitWreath => 'Corona de flores';

  @override
  String get wuselOutfitSunglasses => 'Gafas de sol';

  @override
  String get wuselOutfitScarf => 'Bufanda';

  @override
  String get wuselOutfitHeadphones => 'Auriculares';

  @override
  String get wuselOutfitBow => 'Lazo';

  @override
  String wuselHelloMorning1(String name) {
    return '¡Buenos días, $name!';
  }

  @override
  String wuselHelloMorning2(String name) {
    return '¡Hola, $name! Un día nuevo.';
  }

  @override
  String wuselHelloMorning3(String name) {
    return '¡Hola, $name! Qué bien verte.';
  }

  @override
  String wuselHelloDay1(String name) {
    return '¡Hola, $name!';
  }

  @override
  String wuselHelloDay2(String name) {
    return '¡Ahí estás, $name!';
  }

  @override
  String wuselHelloDay3(String name) {
    return '¡Qué bien verte, $name!';
  }

  @override
  String wuselHelloEvening1(String name) {
    return '¡Buenas tardes, $name!';
  }

  @override
  String wuselHelloEvening2(String name) {
    return '¡Hola, $name! Qué día.';
  }

  @override
  String wuselHelloEvening3(String name) {
    return '¡Hola, $name! Pronto toca descansar.';
  }

  @override
  String wuselHelloNight(String name) {
    return 'Que duermas bien, $name.';
  }

  @override
  String get wuselFactBirthdayYou => '¡Feliz cumpleaños!';

  @override
  String wuselFactBirthday(String name) {
    return '¡Es el cumpleaños de $name!';
  }

  @override
  String wuselFactFirstLesson(String subject) {
    return 'Hoy empiezas con $subject.';
  }

  @override
  String wuselFactTradition(String tradition) {
    return '¡Hoy toca $tradition!';
  }

  @override
  String wuselFactMealDinner(String dish) {
    return 'Esta noche cenamos $dish.';
  }

  @override
  String wuselFactMealLunch(String dish) {
    return 'Hoy almorzamos $dish.';
  }

  @override
  String wuselFactCountdown(String what, String when) {
    return '$what: $when';
  }

  @override
  String wuselBirthdayCheer(String name) {
    return '¡Feliz cumpleaños, $name!';
  }

  @override
  String get wuselAllDone1 => '¡Todo hecho! Ha salido muy bien.';

  @override
  String get wuselAllDone2 => 'Todo marcado. ¡Gracias!';

  @override
  String get wuselAllDone3 => '¡Listo por hoy! La casa te da las gracias.';

  @override
  String get wuselAllDone4 => 'Tu lista está vacía. ¡A jugar!';

  @override
  String get wuselRewardSent1 => '¡Enviado! Ahora decide un adulto.';

  @override
  String get wuselRewardSent2 => 'Tu deseo va de camino.';

  @override
  String get wuselRewardSent3 => '¡Deseo enviado! Un adulto lo mirará.';

  @override
  String wuselBadge(String badge) {
    return '¡Una insignia nueva: $badge!';
  }

  @override
  String get wuselWaiting => 'Un momento…';

  @override
  String get wuselOffline => 'Un momento, busco internet…';

  @override
  String get wuselWallMorning1 => '¡Buenos días a todos!';

  @override
  String get wuselWallMorning2 => '¡Arriba, familia!';

  @override
  String get wuselWallMorning3 => 'Un día nuevo para todos.';

  @override
  String wuselWallMemberDone1(String name) {
    return '¡$name ya lo ha hecho todo por hoy!';
  }

  @override
  String wuselWallMemberDone2(String name) {
    return 'Todo marcado, $name. ¡Gracias!';
  }

  @override
  String wuselWallMemberDone3(String name) {
    return '¡Las tareas de $name están todas hechas!';
  }

  @override
  String wuselWallTradition1(String name) {
    return '¡Hoy es $name!';
  }

  @override
  String wuselWallTradition2(String name) {
    return '¡Qué bien, hoy toca $name!';
  }

  @override
  String wuselWallTradition3(String name) {
    return '¡Buenos días! Hoy toca $name.';
  }

  @override
  String get wuselSetupDone => 'Todo listo. ¡Os damos la bienvenida a casa!';

  @override
  String get wuselHideLine => 'Ocultar lo que dice Wusel';

  @override
  String get wuselFerienFirst1 =>
      'Empiezan las vacaciones. ¡Disfrutad de los días libres!';

  @override
  String get wuselFerienFirst2 => '¡Vacaciones! Hoy empieza el tiempo libre.';

  @override
  String get wuselFerienFirst3 =>
      'Primer día de vacaciones. ¡Disfrutadlo juntos!';

  @override
  String get ambienceFerienFirst => '¡Vacaciones!';

  @override
  String get ambienceFerienLast => 'Mañana vuelve el cole';

  @override
  String get shoppingEmptyTapTile => 'La lista está vacía. Toca una tarjeta.';

  @override
  String get memberBirthday => 'Cumpleaños';

  @override
  String get memberBirthdayHelp =>
      'Aparece en la pantalla de pared ese día, con una cuenta atrás antes.';

  @override
  String get memberBirthdayPick => 'Elegir una fecha';

  @override
  String get memberBirthdayClear => 'Quitar el cumpleaños';

  @override
  String countdownBirthdayOf(String name) {
    return 'Cumpleaños de $name';
  }

  @override
  String countdownBirthdayTurns(String name, int age) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age años',
      one: '1 año',
    );
    return '$name cumple $_temp0';
  }

  @override
  String countdownHomecoming(String name) {
    return '$name vuelve a casa';
  }

  @override
  String countdownSleeps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count noches más',
      one: '1 noche más',
    );
    return '$_temp0';
  }

  @override
  String countdownDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'faltan $count días',
      one: 'falta 1 día',
    );
    return '$_temp0';
  }

  @override
  String countdownInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'en $count días',
      one: 'en 1 día',
    );
    return '$_temp0';
  }

  @override
  String get countdownTomorrow => '¡Mañana!';

  @override
  String get countdownToday => '¡Hoy!';

  @override
  String get kidLookingForward => 'Lo que me hace ilusión';

  @override
  String get todayLookingForward => 'Con ilusión';

  @override
  String get eventIconNone => 'Sin imagen';

  @override
  String get eventIconLabel => 'Imagen';

  @override
  String get eventCountdownTitle => 'Nos hace ilusión';

  @override
  String get eventCountdownHelp =>
      'Cuenta atrás en la pantalla de pared y en la tableta de los niños.';

  @override
  String get eventTraditionTitle => 'Tradición familiar';

  @override
  String get eventTraditionHelp =>
      'Algo que la familia hace una y otra vez. Siempre en la pantalla de pared, con una cinta.';

  @override
  String get eventTraditionMeal => 'Con comida';

  @override
  String get eventTraditionMealHint => 'p. ej. pizza';

  @override
  String get calendarNewTradition => 'Nueva tradición';

  @override
  String get traditionStartersHelp =>
      'Elige una para empezar. Después puedes cambiar el día y la hora.';

  @override
  String get traditionStarterGameNight => 'Noche de juegos';

  @override
  String get traditionStarterPizzaFriday => 'Viernes de pizza';

  @override
  String get traditionStarterFilmNight => 'Noche de cine';

  @override
  String get traditionStarterSundayBreakfast => 'Desayuno del domingo';

  @override
  String get traditionStarterStoryTime => 'Hora del cuento';

  @override
  String get traditionStarterDayOut => 'Día de excursión';

  @override
  String get traditionStarterPizzaMeal => 'Pizza';

  @override
  String get traditionStarterOwn => 'Tradición propia';

  @override
  String get traditionStarterOwnHelp =>
      'Tú eliges el nombre, la imagen y el día.';

  @override
  String traditionStarterWhen(String weekday, String time) {
    return 'Cada $weekday, $time';
  }

  @override
  String traditionStarterWhenAllDay(String weekday) {
    return 'Cada $weekday, todo el día';
  }

  @override
  String get eventIcon_cake => 'Tarta de cumpleaños';

  @override
  String get eventIcon_game_die => 'Juego';

  @override
  String get eventIcon_pizza => 'Pizza';

  @override
  String get eventIcon_cinema => 'Película';

  @override
  String get eventIcon_croissant => 'Desayuno';

  @override
  String get eventIcon_book => 'Lectura';

  @override
  String get eventIcon_hiking => 'Excursión';

  @override
  String get eventIcon_beach => 'Vacaciones';

  @override
  String get eventIcon_plane => 'Viaje';

  @override
  String get eventIcon_zoo => 'Zoo';

  @override
  String get eventIcon_tent => 'Acampada';

  @override
  String get eventIcon_football => 'Deporte';

  @override
  String get eventIcon_music => 'Música';

  @override
  String get eventIcon_gift => 'Regalo';

  @override
  String get eventIcon_balloon => 'Fiesta';

  @override
  String get eventIcon_backpack => 'Colegio';

  @override
  String get eventIcon_swim => 'Natación';

  @override
  String get eventIcon_ferris => 'Feria';

  @override
  String get eventIcon_house => 'Casa';

  @override
  String get eventIcon_star => 'Especial';

  @override
  String get kidWishTitle => 'Tu comida favorita';

  @override
  String get kidWishInvite => '¿Qué te apetece comer esta semana?';

  @override
  String kidWishWaiting(String title) {
    return 'Has pedido $title. Un adulto buscará un día.';
  }

  @override
  String kidWishPlanned(String title, String day) {
    return '¡Tu deseo, $title, será el $day!';
  }

  @override
  String get kidWishMake => 'Pedir';

  @override
  String get kidWishChange => 'Cambiar';

  @override
  String get kidWishSent => 'Tu deseo va de camino.';

  @override
  String get wishPickerTitle => '¿Qué te apetece comer?';

  @override
  String get wishPickerOwn => 'Otra cosa';

  @override
  String get wishPickerOwnHint => 'p. ej. tortitas';

  @override
  String get wishPickerSend => 'Pido esto';

  @override
  String get wishPickerRecipes => 'Nuestras recetas';

  @override
  String get wishPickerSearch => 'Buscar una receta';

  @override
  String get wishPickerNoMatch =>
      'Ninguna receta con ese nombre. Pídela abajo.';

  @override
  String get wishPickerIcon => 'Elige una imagen';

  @override
  String get mealsWishEarlier => 'de la semana pasada';

  @override
  String get mealsWishOlder => 'de hace unas semanas';

  @override
  String get mealsWishMine => 'Pedir algo';

  @override
  String get mealsWishMineChange => 'Cambiar mi deseo';

  @override
  String get mealIcon_pizza => 'Pizza';

  @override
  String get mealIcon_pasta => 'Pasta';

  @override
  String get mealIcon_pancakes => 'Tortitas';

  @override
  String get mealIcon_waffle => 'Gofres';

  @override
  String get mealIcon_burger => 'Hamburguesa';

  @override
  String get mealIcon_fries => 'Patatas fritas';

  @override
  String get mealIcon_hotdog => 'Perrito caliente';

  @override
  String get mealIcon_sandwich => 'Bocadillo';

  @override
  String get mealIcon_taco => 'Tacos';

  @override
  String get mealIcon_burrito => 'Burrito';

  @override
  String get mealIcon_kebab => 'Kebab';

  @override
  String get mealIcon_curry => 'Curry';

  @override
  String get mealIcon_rice => 'Arroz';

  @override
  String get mealIcon_noodles => 'Sopa de fideos';

  @override
  String get mealIcon_soup => 'Sopa o guiso';

  @override
  String get mealIcon_paella => 'Paella';

  @override
  String get mealIcon_salad => 'Ensalada';

  @override
  String get mealIcon_sushi => 'Sushi';

  @override
  String get mealIcon_dumpling => 'Empanadillas';

  @override
  String get mealIcon_chicken => 'Pollo';

  @override
  String get mealIcon_fish => 'Pescado';

  @override
  String get mealIcon_meat => 'Carne';

  @override
  String get mealIcon_egg => 'Huevos';

  @override
  String get mealIcon_falafel => 'Falafel';

  @override
  String get mealIcon_fondue => 'Fondue';

  @override
  String get mealIcon_pie => 'Pastel salado';

  @override
  String get mealIcon_cake => 'Tarta';

  @override
  String get mealIcon_ice_cream => 'Helado';

  @override
  String get mealIcon_bread => 'Pan';

  @override
  String get mealIcon_pretzel => 'Pretzel';

  @override
  String get mealIcon_croissant => 'Cruasán';

  @override
  String get mealIcon_potato => 'Patatas';

  @override
  String get mealIcon_cheese => 'Queso';

  @override
  String get mealIcon_porridge => 'Gachas';

  @override
  String get mealIcon_vegetables => 'Verduras';

  @override
  String get mealsWishesTray => 'Deseos';

  @override
  String mealsWishChip(String name, String title) {
    return '$name: $title';
  }

  @override
  String get mealsWishPlan => 'Planificar';

  @override
  String get mealsWishRemove => 'Quitar el deseo';

  @override
  String mealsWishedBy(String name) {
    return 'Deseo de $name';
  }

  @override
  String mealsTraditionSuggestion(String meal, String tradition) {
    return 'Planificar $meal ($tradition)';
  }

  @override
  String get tableQuestionTitle => 'Pregunta en la mesa';

  @override
  String get tableQuestionNext => 'Otra pregunta';

  @override
  String get tableQuestionAnswer => 'Ver la respuesta';

  @override
  String tableQuestionFrom(String name) {
    return 'Pregunta de $name';
  }

  @override
  String get tableQuestionsManage => 'Nuestras preguntas';

  @override
  String get tableQuestionAdd => 'Añadir una pregunta';

  @override
  String get tableQuestionAddHint => '¿Qué quieres preguntar en la mesa?';

  @override
  String get tableQuestionHide => 'No volver a preguntar esto';

  @override
  String get tableQuestionRemove => 'Quitar la pregunta';

  @override
  String get tableQuestionsHidden => 'Preguntas apartadas';

  @override
  String get tableQuestionShowAgain => 'Volver a preguntar';

  @override
  String get kidWishWithdraw => 'Retirar';

  @override
  String get kidWishAnother => 'Pedir otra';

  @override
  String get mealsWishSlotFree => 'Nada planificado';

  @override
  String get mealsWishReplaceTitle => '¿Reemplazar la comida?';

  @override
  String mealsWishReplaceBody(
    String dish,
    String slot,
    String day,
    String wish,
  ) {
    return 'Ya planificado: $dish ($slot, $day). ¿Planificar el deseo $wish en su lugar? Quien cocina, la hora y las raciones se mantienen.';
  }

  @override
  String get mealsWishReplace => 'Reemplazar';

  @override
  String get errSlotTaken => 'Ya hay algo planificado para esa comida.';

  @override
  String get tableQuestionDismiss => 'Ocultar en esta comida';

  @override
  String get weekReviewTitle => 'Nuestra semana';

  @override
  String get weekReviewOpen => 'Repasar nuestra semana';

  @override
  String get weekReviewTogether => 'Lo que hicimos juntos';

  @override
  String weekReviewChores(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tareas hechas',
      one: '1 tarea hecha',
      zero: 'Una semana para respirar',
    );
    return '$_temp0';
  }

  @override
  String get weekReviewMoments => 'Cada uno tuvo su momento';

  @override
  String get weekReviewMeals => 'Qué rico';

  @override
  String get weekReviewNewRecipe => 'nuevo';

  @override
  String get weekReviewTraditions => 'Nuestras tradiciones';

  @override
  String get weekReviewNext => 'La semana que viene nos hace ilusión';

  @override
  String get weekReviewCalmAhead => 'Viene una semana tranquila.';

  @override
  String weekReviewCardOf(int index, int count) {
    return 'Tarjeta $index de $count';
  }

  @override
  String get weekReviewNextCard => 'Tarjeta siguiente';

  @override
  String get weekReviewPreviousCard => 'Tarjeta anterior';

  @override
  String weekHighlightBadge(String title) {
    return 'Insignia nueva: $title';
  }

  @override
  String weekHighlightStreak(String title) {
    return '$title, cada día';
  }

  @override
  String get weekHighlightAllDone => 'tuvo un día con todo hecho';

  @override
  String weekHighlightReward(String title) {
    return 'Premio: $title';
  }

  @override
  String weekHighlightWish(String title) {
    return 'Deseo en la mesa: $title';
  }

  @override
  String weekHighlightCooked(String title) {
    return 'cocinó $title';
  }

  @override
  String weekHighlightAttended(String title) {
    return 'estuvo en $title';
  }

  @override
  String get weekHighlightHelped => 'ayudó con las tareas';

  @override
  String get weekHighlightHere => 'formó parte de nuestra semana';

  @override
  String settingsOwnTitle(String name) {
    return 'Ajustes de $name';
  }

  @override
  String get settingsGroupPersonalTitle => 'Personal';

  @override
  String get settingsGroupPersonalSubtitle =>
      'Wusel, sonidos y recordatorios para ti';

  @override
  String get settingsGroupFamilyTitle => 'Familia';

  @override
  String get settingsGroupFamilySubtitle =>
      'Nombre, zona horaria, miembros y semana habitual';

  @override
  String get settingsGroupTasksTitle => 'Tareas y recompensas';

  @override
  String get settingsGroupTasksSubtitle =>
      'Puntos, comodines de racha y aprobaciones';

  @override
  String get settingsGroupCalendarTitle => 'Calendario y colegio';

  @override
  String get settingsGroupCalendarSubtitle =>
      'Eventos, cambios de horario y compartir';

  @override
  String get settingsGroupMealsTitle => 'Comidas';

  @override
  String get settingsGroupMealsSubtitle =>
      'Comida caliente, comida deseada y almuerzo en el cuidado';

  @override
  String get settingsGroupRitualsTitle => 'Rituales';

  @override
  String get settingsGroupRitualsSubtitle =>
      'Pregunta en la mesa, nuestra semana, cuentas atrás';

  @override
  String get settingsGroupCelebrationsTitle => 'Celebraciones y estaciones';

  @override
  String get settingsGroupCelebrationsSubtitle =>
      'Adviento, Pascua, Nochevieja, cumpleaños y estaciones';

  @override
  String get settingsGroupKitchenTitle => 'Pantalla de la cocina';

  @override
  String get settingsGroupKitchenSubtitle =>
      'Nombres, cambio de semana y momentos del día';

  @override
  String get settingsGroupDevicesTitle => 'Dispositivos';

  @override
  String get settingsGroupDevicesSubtitle =>
      'Este dispositivo y todos los de la familia';

  @override
  String get settingsGroupAccountTitle => 'Cuenta y seguridad';

  @override
  String get settingsGroupAccountSubtitle =>
      'Inicio de sesión, contraseña, doble factor, salir de la familia';

  @override
  String get settingsGroupServerTitle => 'Servidor';

  @override
  String get settingsGroupServerSubtitle =>
      'Dirección, código QR y cambio de servidor';

  @override
  String get settingsGroupHelpTitle => 'Ayuda e información';

  @override
  String get settingsGroupHelpSubtitle =>
      'Primeros pasos, versiones, licencias';

  @override
  String get settingsSectionWusel => 'Wusel';

  @override
  String get settingsSectionSound => 'Sonido';

  @override
  String get settingsSectionNotifications => 'Notificaciones';

  @override
  String get settingsSectionTableQuestion => 'Pregunta en la mesa';

  @override
  String get settingsSectionWeekReview => 'Repaso de la semana';

  @override
  String get settingsSectionCountdowns => 'Cuentas atrás';

  @override
  String get settingsSectionHolidays => 'Fiestas';

  @override
  String get settingsSectionThroughYear => 'A lo largo del año';

  @override
  String get settingsSectionAllDevices => 'Todos los dispositivos';

  @override
  String get settingsSectionLeave => 'Salir o eliminar';

  @override
  String get settingsSectionOther => 'Otros ajustes';

  @override
  String get familyProfileTitle => 'Perfil de la familia';

  @override
  String get settingsMembersSubtitle =>
      'Nombres, colores, roles y el orden en la pared';

  @override
  String get calendarMonth => 'Mes';

  @override
  String get calendarWeekNumberShort => 'Sem';

  @override
  String calendarWeekNumberLabel(int week) {
    return 'Semana $week';
  }

  @override
  String calendarMonthMore(int count) {
    return '+$count';
  }

  @override
  String calendarMonthOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count citas más',
      one: '1 cita más',
    );
    return '$_temp0';
  }

  @override
  String calendarMonthFerien(String name) {
    return 'Vacaciones escolares: $name';
  }

  @override
  String get calendarMonthOpenDay => 'Abrir el día';
}

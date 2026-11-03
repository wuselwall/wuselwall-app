/// The demo normally follows real time. Qualification fixes its data clock before
/// creating repositories, independently of JavaScript clocks or the host date.
abstract final class DemoClock {
  static DateTime? fixedNow;

  static DateTime now() => fixedNow ?? DateTime.now();
}

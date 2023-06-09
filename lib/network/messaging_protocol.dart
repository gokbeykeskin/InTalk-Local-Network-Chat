// The messaging protocol used by the server and client.
class MessagingProtocol {
  static const login = 'li';
  static const heartbeat = 'hb';
  static const broadcastMessage = 'bc';
  static const privateMessage = 'pv';
  static const trustedDevice = 'td';
  static const bannedDevice = 'bd';
  static const untrustDevice = 'ut';
  static const unbanDevice = 'ub';
  static const logout = 'lo';
  static const nameUpdate = 'nu';
  static const broadcastImageStart = 'bi';
  static const broadcastImageContd = 'cb';
  static const broadcastImageEnd = 'eb';
  static const privateImageStart = 'pi';
  static const privateImageContd = 'ci';
  static const privateImageEnd = 'ei';
  static const rejected = 'rj';
  static const serverIntermediateKey = 'sk';
  static const clientNumber = 'cn';
}

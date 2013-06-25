if (!window.jQuery) { throw("please require jquery.js first!"); }
if (!window.Faye) { throw("please require faye-browser.js first!"); }

// Faye 连接
Faye.init_online_client = function(opts) {
  opts = opts || {};

  // validate params
  if (!opts.faye_url) { throw("faye_url is not defined!"); }
  opts.client_opts = $.extend({
    timeout: 10, // 只用于client连server时的主动检测timeout。如果client自行disconnect，那就没办法了。
    interval: 5, // handshake every 5 seconds
    retry: 5
  }, opts.client_opts);
  var faye = new Faye.Client(opts.faye_url, opts.client_opts);
  // faye.getState() // "DISCONNECTED"
  // faye.disable('websocket'); // cause loop connect error
  faye.disable('autodisconnect'); // 就会关了页面还是保持连接

  // copied from https://github.com/cloudfuji/kandan/
  // Note that these events do not reflect the status of the client’s session, http://faye.jcoglan.com/browser/transport.html
  // The transport is only considered down if a request or WebSocket connection explicitly fails, or times out, indicating the server is unreachable.
  faye.bind("transport:down", function() { console.log("Comm link to Cybertron is down!"); });
  faye.bind("transport:up", function() { console.log("Comm link is up!"); });

  // 参考 https://github.com/cloudfuji/kandan/ 在线聊天系统
  // http://faye.jcoglan.com/ruby/extensions.html
  opts.auth_opts = opts.auth_opts || {};
  opts.auth_opts.current_user = opts.auth_opts.current_user || {};
  if (!opts.auth_opts.room_channel || !opts.auth_opts.time_channel || !opts.auth_opts.current_user.uid || !opts.auth_opts.current_user.uname) {
    console.log("auth_opts is ", opts.auth_opts);
    throw("auth_opts is not valid. see valided format in README");
  }
  var AuthExtension = {
    outgoing: function (message, callback) {
      message.auth = (message.auth || {});
      $.extend(message.auth, opts.auth_opts);

      callback(message);
    }
  };
  faye.addExtension(AuthExtension);

  // notice server to check my clientId after a few seconds, if there's
  // no connection, and disconnect my clientId.
  $(window).bind('beforeunload', function(event) {
    faye.publish("/faye_online/before_leave");
  });


  return faye;
}; 

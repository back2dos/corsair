package corsair;

class Middleware {
  static public function custom(options:{ extract: tink.Url->Option<String>, redirect:Redirect }):Handler->Handler 
    return function (handler) 
      return function (req:IncomingRequest) 
        return switch options.extract(req.header.url) {
          case Some(to): Forward.request(req, to, options.redirect);
          case None: handler.process(req);
        } 

  static public function create(?options:{ paramName:String }):Handler->Handler {
    var paramName = switch options {
      case null | { paramName: null }: 'proxy-to';
      case { paramName: v }: v;
    }    
    return 
      custom({
        extract: function (url) {
          var to = url.query.toMap()[paramName].toString();
          return 
            if (url.path == '/' && to != null) Some(to);
            else None;
        },
        redirect: function (ctx) return 'http://${ctx.self}/?$paramName=${ctx.target}'
      });
  }
}
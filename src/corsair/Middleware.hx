package corsair;

import tink.http.Client;

class Middleware {
  static public function custom(options:{ extract: tink.Url->Option<String>, redirect:Redirect, ?augment:Processors }):Handler->Handler 
    return function (handler) 
      return function (req:IncomingRequest) 
        return switch options.extract(req.header.url) {
          case Some(to): 
            Forward.request(req, to, options);
          case None: handler.process(req);
        } 

  static public function create(?options:{ ?paramName:String, ?augment:Processors }):Handler->Handler {
    if (options == null)
      options = {};
    var paramName = switch options.paramName {
      case null: 'proxy-to';
      case v: v;
    }    
    return 
      custom({
        extract: function (url) {
          var to = url.query.toMap()[paramName].toString();
          return 
            if (url.path == '/' && to != null) Some(to);
            else None;
        },
        redirect: function (ctx) {
          return 'http://${ctx.self}/?' + tink.url.Query.build().add(paramName, (ctx.from:tink.Url).resolve(ctx.to).toString()).toString(); //TODO: treat relative URLs
        },
        augment: options.augment,
      });
  }
}
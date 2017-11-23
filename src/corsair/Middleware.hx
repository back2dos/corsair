package corsair;

import tink.http.Handler;
import tink.http.Request;

class Middleware {
  static public function create(?options:{ paramName:String }):Handler->Handler {
    var paramName = switch options {
      case null | { paramName: null }: 'proxy-to';
      case { paramName: v }: v;
    }    
    return function (handler) {
      return function (req:IncomingRequest) {
        var to = req.header.url.query.toMap()[paramName].toString();
        return 
          if (req.header.url.path == '/' && to != null)
            Forward.request(req, to, function (ctx) return 'http://${ctx.self}/?$to=${ctx.target}');
          else
            handler.process(req);
        }
    }
  }
}
# corsair

This library enables your server to proxy CORS requests.

```haxe
container.run(
  corsair.Middleware.create({ paramName: 'target' })(
    yourHandler
  )
)
```

This way any requests to `/?target=<someUrl>` will be forwarded to that URL. Also works with POST and other methods. Any `Set-Cookie` headers have their `domain` cleared (if one is set) and their `secure` removed. Any `Location: <redirectUrl>` headers are rewritten to point to `/?target=<redirectUrl>`.

If `paramName` is not specified, it will default to `proxy-to`.

It goes without saying that this is purely for local development. Proxying arbitrary traffic through production servers is advised against, unless you can think of an *extremely* good reason to allow for it.
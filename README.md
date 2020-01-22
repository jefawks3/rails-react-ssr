# RailsReactSSR

RailsReactSSR is a light weight JS server side rendering utility that takes advantage of `Webpacker` and `NodeJS`.

## Motivation

In my latest project I designed my application to use Rails for my API endpoints and `ReactJS` with `react-router` to 
handle routing and handle the front end. I needed a basic tool that would not add a lot of bloat, be able to handle 
server side rendering while allowing me to process the response (i.e. handle redirects from the router) and did not
force me to use any packages or make decisions for me on how to structure my ReactJS code.

## Dependencies

- [Ruby On Rails](https://rubyonrails.org/)
- [Webpacker](https://github.com/rails/webpacker)
- [NodeJS](https://nodejs.org/)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rails-react-ssr'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install rails-react-ssr

## Usage

`RailsReactSSR::ServerRunner.exec!(bundle, props:, outputTemp:, max_tries:, delay:)`

* `bundle` is the path or name of the bundle in the `app/javascript/packs` directory

(optional)

* `props` is a hash that will converted to a JSON plain object and passed to the server
* `outputTemp` is either:
  * a boolean, where true will output the compiled server code to `tmp/ssr/[bundle].js`
  * a string that is the full path to the file to write to
* `max_tries` is the number of retries when fetching the bundle from teh `webpack-dev-server`
* `delay` is the time in ms between each retry

#### Basic usage

##### `server.js`
```typescript jsx
// Some processing here

stdout(yourHtmlOutput);
```

##### Your controller
```ruby
def index
  render html: RailsReactSSR::ServerRunner.exec!('server.js')
end
```

#### Passing properties to the server

##### From the controller:

```ruby
def index
  render html: RailsReactSSR::ServerRunner.exec!('server.js', props: {current_user: current_user})
end
```

##### From the server code:

```javascript
  ...

  // Do something with the user  
  console.log('Current user', serverProps.currentUser.username);

  ...
```

The keys in the properties passed to the server will be transformed to camelized strings.

#### Handling redirects with `React-Router-Web`

Below is an example of handling redirects with [`react-router`](https://reacttraining.com/react-router/).
The principle should be the same for any routing packages.

##### `server.js`
```typescript jsx
// Not the complete story

const context = {};

const RedirectWithStatus = ({from, to, status}) => {
    return (
      <Route
        render={({ staticContext }) => {
          // there is no `staticContext` on the client, so
          // we need to guard against that here
          if (staticContext) staticContext.status = status;
          return <Redirect from={from} to={to} />;
        }}
      />
    );
}

const markup = ReactDOMServer.renderToString(
    <StaticRouter location={serverProps.location} context={context}>
        <Switch>
            <RedirectWithStatus 
                status={301} 
                from="/users" 
                to="/profiles" />
            <RedirectWithStatus
                status={302}
                from="/courses"
                to="/dashboard"
            />
        </Switch>
    </StaticRouter>
);

const output = {
 html: markup, 
 logs: recordedLogs, 
 redirect: context.url,
 status: context.status 
};

stdout(JSON.stringify(output));
```
More details on SSR and `react-router` at https://reacttraining.com/react-router/web/guides/server-rendering

##### Your controller
```ruby
def index
  output = RailsReactSSR::ServerRunner.exec!('server.js', props: {current_user: current_user, location: request.fullpath})
  
  react_response = ActiveSupport::JSON.decode output.split(/[\r\n]+/).reject(&:empty?).last

  react_response.deep_symbolize_keys!

  if react_response[:redirect]
    redirect_to react_response[:redirect], status: 302
  else
    render html: react_response[:html]
  end
end
```

### Caching Example

To improve the response time from the server, you should consider caching.

Things to consider:
1) Using a cache key that is not the same for every route if you are using a JS routing package.
2) How large the response is form the JS server.

```ruby

def index
  ## Do something to the path to generate a key that represents it in the server routes
  cache_key = generate_cache_key_from_uri request.fullpath  
  
  output = Rails.cache.fetch cache_key, expires: 12.hours, race_condition_ttl: 1.minute, namespace: :react_server do
            RailsReactSSR::ServerRunner.exec!('server.js', props: {current_user: current_user, location: request.fullpath})
          end
  
  handle_server_response output
end

```

## Common Issues with SSR and Rails

### I'm unable to execute code with webpacker-dev-server running.

The `webpacker-dev-server` injects a websocket when `inline` or `hmr` flags are set to true in for the `dev_server`
configuration in `webpacker.yml`. Make sure these are set to **false** if you plan on implementing SSR.

### `document` or `window` is not defined

Global objects like `document` or `window` that are specific to browsers are not set when running the javascript on 
the server; so it's best to wrap any code, or avoid using it outside of `componentDidMount`, `componentDidUpdate` or
`componentWillUnmount`.

## Alternatives

There are several alternatives that are more comprehensive and might be a better fit for your use case:

1) [ReactOnRails](https://github.com/shakacode/react_on_rails)
2) [react-rails](https://github.com/reactjs/react-rails)
3) [reactssr-rails](https://github.com/towry/reactssr-rails)

## Issues

Report bugs at https://github.com/jefawks3/rails-react-ssr.
Please make sure to include how to reproduce the issue, otherwise it might be ignored.

## Contributing

1) Fork it (https://github.com/jefawks3/rails-react-ssr)
2) Create your feature branch (git checkout -b my-new-feature)
3) Commit your changes (git commit -am 'Add some feature')
4) Push to the branch (git push origin my-new-feature)
5) Create a new Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).


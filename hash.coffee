if Meteor.isServer

  sessions = {}

  Meteor.methods
    rememberSession: (hash, serialized) ->
      console.log 'rememberSession', hash, serialized
      sessions[hash] = serialized

    fetchSession: (hash) ->
      session = sessions[hash]
      console.log 'fetchSession', hash, '->', session
      session


return unless Meteor.isClient

isPlainObject = (x) ->
  _.isObject(x) and not (
    _.isString(x) or
    _.isNumber(x) or
    _.isBoolean(x) or
    _.isDate(x) or
    _.isArray(x)
  )

orderedStringify = (x) ->
  if isPlainObject(x)
    r = '{'
    _.each _.keys(x).sort(), (key, index) ->
      r += ',' if index isnt 0
      r += JSON.stringify(key) + ':' + orderedStringify(x[key])
    r + '}'
  else
    EJSON.stringify(x)

sha256_base64 = (input) ->
  hexHash = Meteor._srp.SHA256(input);
  binaryHash = ''
  for i in [0...hexHash.length] by 2
    binaryHash += String.fromCharCode(parseInt(hexHash.substr(i, 2), 16))
  btoa(binaryHash).replace(/\=+$/, '')

writePending = false
changingSession = false

writeSession = ->
  serialized = orderedStringify(Session.keys)
  hash = sha256_base64(serialized)
  Meteor.call 'rememberSession', hash, serialized
  writePending = false
  history.pushState(null, '', '/' + hash)
Meteor.__sessionSetHook = ->
  unless writePending or changingSession
    writePending = true
    setTimeout(writeSession, 0)

onpopstate = ->
  hash = window.location.pathname.substr(1)
  Meteor.call 'fetchSession', hash, (err, serialized) ->
    return if err or not serialized?
    unserialized = EJSON.parse(serialized)
    changingSession = true
    _.each(unserialized, (value, key) ->
      value = EJSON.parse(value)
      Session.set key, value
    )
    changingSession = false

window.addEventListener('popstate', onpopstate, false)

# Firefox doesn't fire the popstate event on window load
Meteor.startup -> onpopstate()

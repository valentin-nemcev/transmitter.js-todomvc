'use strict'

{inspect} = require 'util'

$ = require 'jquery'

window.JQuery = $
window.Transmitter = require 'transmitter'

Todos = require './model'
TodoStorage = require './storage'

HeaderView = require './views/header'
MainView   = require './views/main'
FooterView = require './views/footer'


class App extends Transmitter.Nodes.Record

  constructor: ->
    @todos = new Todos()
    @todoStorage = new TodoStorage('todos-transmitter')

    @headerView = new HeaderView($('.header'))
    @mainView = new MainView($('.main'))
    @footerView = new FooterView($('.footer'))

    @locationHash = new Transmitter.Browser.LocationHash()
    @activeFilter = new Transmitter.Nodes.Variable()
    @locationHashChannel =
      new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource @locationHash
      .toTarget @activeFilter
      .withTransform (locationHashPayload) ->
        locationHashPayload.map (value) ->
          switch value
            when '#/active' then 'active'
            when '#/completed' then 'completed'
            else 'all'


  init: (tr) ->
    @todos.init(tr)

    @todoStorage.setDefault([
      {title: 'Todo 1', completed: no},
      {title: 'Todo 2', completed: yes}
    ])

    @todoStorage.createTodosChannel(@todos).init(tr)
    @todoStorage.load(tr)

    @headerView.init(tr)
    @headerView.createTodosChannel(@todos).init(tr)

    @mainView.init(tr)
    @mainView.createTodosChannel(@todos, @activeFilter).init(tr)

    @footerView.init(tr)
    @footerView.createTodosChannel(@todos, @activeFilter).init(tr)

    @locationHashChannel.init(tr)
    @locationHash.originate(tr)



Element::inspect = -> '<' + @tagName + ' ... />'
$.Event::inspect = -> '[$Ev ' + @type + ' ... ]'
Event::inspect = -> '[Ev ' + @type + ' ... ]'

Transmitter.Transmission::loggingFilter = (msg) ->
  # msg.match(/\btodoList|nonBlankTodoList/)
  # msg.match(/label(Input)?Var|MM/)

Transmitter.Transmission::loggingIsEnabled = no

window.app = new App()

Transmitter.startTransmission (tr) -> app.init(tr)

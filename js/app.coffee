'use strict'

{inspect} = require 'util'

$ = require 'jquery'
keycode = require 'keycode'

window.JQuery = $
window.Transmitter = require 'transmitter'

class VisibilityToggleVar extends Transmitter.Nodes.Variable
  constructor: (@$element) ->
  set: (state) -> @$element.toggle(!!state); this
  get: -> @$element.is(':visible')


class Todo extends Transmitter.Nodes.Record

  inspect: -> "[Todo #{inspect @labelVar.get()}]"

  init: (tr, defaults = {}) ->
    {label, isCompleted} = defaults
    @labelVar.init(tr, label) if label?
    @isCompletedVar.init(tr, isCompleted) if isCompleted?
    return this

  @defineVar 'labelVar'

  @defineVar 'isCompletedVar'


class TodoView extends Transmitter.Nodes.Record

  inspect: -> "[TodoView #{inspect @todo.labelVar.get()}]"

  constructor: (@todo) ->
    @$element = $('<li/>').append(
      $('<div/>', class: 'view').append(
        $('<input/>', class: 'toggle', type: 'checkbox')
        $('<label/>')
        $('<button/>', class: 'destroy')
      )
      $('<input/>', class: 'edit')
    )


  init: (tr) ->
    @editStateVar.init(tr, off)
    @acceptEditChannel.init(tr)
    @rejectEditChannel.init(tr)
    @editStateChannel = new EditStateChannel(this).init(tr)
    return this


  @defineLazy 'startEditEvt', -> @labelDblclickEvt
  @defineLazy 'acceptEditEvt', -> new Transmitter.Nodes.RelayNode()
  @defineLazy 'rejectEditEvt', -> new Transmitter.Nodes.RelayNode()

  @defineLazy 'acceptEditChannel', ->
    new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource @inputKeypressEvt
      .toTarget @acceptEditEvt
      .withTransform (msg) ->
        if keycode(msg.get?()) is 'enter'
          Transmitter.Payloads.Variable.setConst(yes)
        else
          Transmitter.Payloads.noop()

  @defineLazy 'rejectEditChannel', ->
    new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource @inputKeypressEvt
      .toTarget @rejectEditEvt
      .withTransform (msg) ->
        if keycode(msg.get?()) is 'esc'
          Transmitter.Payloads.Variable.setConst(yes)
        else
          Transmitter.Payloads.noop()


  class EditStateChannel extends Transmitter.Channels.CompositeChannel

    constructor: (@todoView) ->

    @defineChannel ->
      new Transmitter.Channels.SimpleChannel()
        .inBackwardDirection()
        .fromSource @todoView.startEditEvt
        .toTarget @todoView.editStateVar
        .withTransform (msg) ->
          if msg.map? then msg.map( -> yes) else msg

    @defineChannel ->
      new Transmitter.Channels.SimpleChannel()
        .inBackwardDirection()
        .fromSource @todoView.acceptEditEvt
        .toTarget @todoView.editStateVar
        .withTransform (msg) ->
          if msg.map? then msg.map( -> no) else msg

    @defineChannel ->
      new Transmitter.Channels.SimpleChannel()
        .inBackwardDirection()
        .fromSource @todoView.rejectEditEvt
        .toTarget @todoView.editStateVar
        .withTransform (msg) ->
          if msg.map? then msg.map( -> no) else msg


  createRemoveTodoChannel: ->
    new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource @destroyClickEvt
      .withTransform (payload) =>
        if payload.get?
          Transmitter.Payloads.List.removeConst(@todo)
        else
          Transmitter.Payloads.noop()


  @defineLazy 'labelVar', ->
    new Transmitter.DOMElement.TextVar(@$element.find('label')[0])

  @defineLazy 'labelInputVar', ->
    new Transmitter.DOMElement.InputValueVar(@$element.find('.edit')[0])

  @defineLazy 'isCompletedInputVar', ->
    checkbox = @$element.find('.toggle')[0]
    new Transmitter.DOMElement.CheckboxStateVar(checkbox)

  @defineLazy 'labelDblclickEvt', ->
    new Transmitter.DOMElement.DOMEvent(@$element.find('label')[0], 'dblclick')

  @defineLazy 'inputKeypressEvt', ->
    new Transmitter.DOMElement.DOMEvent(@$element.find('.edit')[0], 'keyup')

  @defineLazy 'destroyClickEvt', ->
    new Transmitter.DOMElement.DOMEvent(@$element.find('.destroy')[0], 'click')


  class ClassToggleVar extends Transmitter.Nodes.Variable
    constructor: (@$element, @class) ->
    set: (state) -> @$element.toggleClass(@class, !!state); this
    get: -> @$element.hasClass(@class)


  @defineLazy 'isCompletedClassVar', ->
    new ClassToggleVar(@$element, 'completed')

  @defineLazy 'editStateVar', ->
    new ClassToggleVar(@$element, 'editing')



class TodoViewChannel extends Transmitter.Channels.CompositeChannel

  inspect: ->
    @todo.inspect() + '-' + @todoView.inspect()


  constructor: (@todo, @todoView) ->


  @defineChannel ->
    new Transmitter.Channels.VariableChannel()
      .withOrigin @todo.labelVar
      .withDerived @todoView.labelVar


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource @todoView.labelInputVar
      .fromSource @todoView.acceptEditEvt
      .toTarget @todo.labelVar
      .withTransform (payloads) =>
        label  = payloads.get(@todoView.labelInputVar)
        accept = payloads.get(@todoView.acceptEditEvt)

        if accept.get? then label else accept


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSource @todo.labelVar
      .fromSource @todoView.startEditEvt
      .fromSource @todoView.rejectEditEvt
      .toTarget @todoView.labelInputVar
      .withTransform (payloads) =>
        label  = payloads.get(@todo.labelVar)
        start  = payloads.get(@todoView.startEditEvt)
        reject = payloads.get(@todoView.rejectEditEvt)

        if start.get? or reject.get?
          label
        else
          Transmitter.Payloads.noop()


  @defineChannel ->
    new Transmitter.Channels.VariableChannel()
      .withOrigin @todo.isCompletedVar
      .withDerived @todoView.isCompletedInputVar


  @defineChannel ->
    new Transmitter.Channels.VariableChannel()
      .inForwardDirection()
      .withOrigin @todo.isCompletedVar
      .withDerived @todoView.isCompletedClassVar



class TodoListView extends Transmitter.Nodes.Record

  constructor: (@$element) ->

  init: (tr) ->
    @viewElementListChannel.init(tr)

  @defineLazy 'viewList', ->
    new Transmitter.Nodes.List()

  @defineLazy 'elementList', ->
    new Transmitter.DOMElement.ChildrenList(@$element[0])

  @defineLazy 'viewElementListChannel', ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSource @viewList
      .toTarget @elementList
      .withTransform (views) ->
        views.updateMatching(
          (view) -> view.$element[0]
          (view, element) -> view.$element[0] == element
        )



class TodoListViewChannel extends Transmitter.Channels.CompositeChannel

  inspect: ->
    @todoList.inspect() + '-' + @todoListView.inspect()


  constructor: (@todoList, @todoListWithComplete, @todoListView, @activeFilter) ->


  @defineLazy 'removeTodoChannelList', ->
    new Transmitter.ChannelNodes.ChannelList()


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .fromSource @todoListView.viewList
      .toConnectionTarget @removeTodoChannelList
      .withTransform (todoViews) =>
        todoViews?.map (todoView) =>
          todoView.createRemoveTodoChannel()
            .toTarget(@todoList)


  @defineLazy 'filteredTodoList', ->
    new Transmitter.Nodes.List()


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSource @todoListWithComplete
      .fromSource @activeFilter
      .toTarget @filteredTodoList
      .withTransform (payloads) =>
        todoListPayload = payloads.get(@todoListWithComplete)
        activeFilterPayload = payloads.get(@activeFilter)
        filter = activeFilterPayload.get()
        todoListPayload
          .filter ([todo, isCompleted]) ->
            switch filter
              when 'active'    then !isCompleted
              when 'completed' then isCompleted
              else true
          .map ([todo]) -> todo


  @defineChannel ->
    new Transmitter.Channels.ListChannel()
    .inForwardDirection()
    .withOrigin @filteredTodoList
    .withMapOrigin (todo, tr) -> new TodoView(todo).init(tr)
    .withDerived @todoListView.viewList
    .withMatchOriginDerived (todo, todoView) -> todo == todoView.todo
    .withMatchOriginDerivedChannel (todo, todoView, channel) ->
      channel.todo == todo and channel.todoView == todoView
    .withOriginDerivedChannel (todo, todoView) ->
      new TodoViewChannel(todo, todoView)



class NewTodoView extends Transmitter.Nodes.Record

  constructor: (@$element) ->
    @element = @$element[0]


  init: (tr) ->
    @clearNewTodoLabelInputChannel.init(tr)
    return this


  @defineLazy 'newTodoLabelInputVar', ->
    new Transmitter.DOMElement.InputValueVar(@element)


  @defineLazy 'newTodoKeypressEvt', ->
    new Transmitter.DOMElement.DOMEvent(@element, 'keyup')


  createNewTodoChannel: ->
    new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource @newTodoLabelInputVar
      .fromSource @newTodoKeypressEvt
      .withTransform (payloads, tr) =>
        label    = payloads.get(@newTodoLabelInputVar)
        keypress = payloads.get(@newTodoKeypressEvt)

        key = keycode(keypress.get?())
        if key is 'enter'
          todo = new Todo().init(tr, label: label.get())
          Transmitter.Payloads.List.appendConst(todo)
        else
          Transmitter.Payloads.noop()


  @defineLazy 'clearNewTodoLabelInputChannel', ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSource @newTodoKeypressEvt
      .toTarget @newTodoLabelInputVar
      .withTransform (keypress) ->
        key = keycode(keypress.get?())
        if key in ['esc', 'enter']
          Transmitter.Payloads.Variable.setConst('')
        else
          Transmitter.Payloads.noop()



class TodoListFooterView extends Transmitter.Nodes.Record

  constructor: (@$element) ->


  @defineLazy 'completeCountVar', ->
    new Transmitter.DOMElement.TextVar(@$element.find('.todo-count')[0])


  @defineLazy 'clearCompletedIsVisibleVar', ->
    new VisibilityToggleVar(@$element.find('.clear-completed'))


  @defineLazy 'clearCompletedClickEvt', ->
    new Transmitter.DOMElement
      .DOMEvent(@$element.find('.clear-completed')[0], 'click')


  @defineLazy 'isVisibleVar', ->
    new VisibilityToggleVar(@$element)

  @defineLazy 'activeFilter', ->
    $filters = @$element.find('.filters')
    new class ActiveFilterSelector extends Transmitter.Nodes.Variable
      get: ->
        ($filters.find('a.selected').attr('href') ? '')
          .match(/\w*$/)[0] || 'all'
      set: (filter) ->
        filter = '' if filter is 'all'
        $filters.find('a').removeClass('selected')
          .filter("[href='#/#{filter}']").addClass('selected')



class TodoListFooterViewChannel extends Transmitter.Channels.CompositeChannel

  constructor:
    (@todoList, @todoListWithComplete, @todoListFooterView, @activeFilter) ->


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSource @activeFilter
      .toTarget @todoListFooterView.activeFilter


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSource @todoListWithComplete
      .toTarget @todoListFooterView.completeCountVar
      .withTransform (todoListWithComplete) ->
        Transmitter.Payloads.Variable.setLazy(->
          count = todoListWithComplete.get()
            .filter(([todo, isCompleted]) -> !isCompleted)
            .length
          items = if count is 1 then 'item' else 'items'
          "#{count} #{items} left"
        )


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSource @todoListWithComplete
      .toTarget @todoListFooterView.clearCompletedIsVisibleVar
      .withTransform (todoListWithComplete) ->
        Transmitter.Payloads.Variable.setLazy(->
          count = todoListWithComplete.get()
            .filter(([todo, isCompleted]) -> isCompleted)
            .length
          count > 0
        )


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource @todoListFooterView.clearCompletedClickEvt
      .fromSource @todoListWithComplete
      .toTarget @todoList
      .withTransform (payloads) =>
        clearCompleted = payloads.get(@todoListFooterView.clearCompletedClickEvt)
        todoListWithComplete = payloads.get(@todoListWithComplete)
        if clearCompleted.get?
          todoListWithComplete
            .filter ([todo, isCompleted]) -> !isCompleted
            .map ([todo]) -> todo
        else
          clearCompleted


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSource @todoList
      .toTarget @todoListFooterView.isVisibleVar
      .withTransform (payload) ->
        Transmitter.Payloads.Variable.setLazy ->
          payload.get().length > 0




class ToggleAllChannel extends Transmitter.Channels.CompositeChannel

  constructor:
    (@todoList, @todoListWithComplete, @toggleAllCheckboxVar, @toggleAllChangeEvt) ->

  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSource @todoListWithComplete
      .toTarget @toggleAllCheckboxVar
      .withTransform (todoListWithComplete) ->
        Transmitter.Payloads.Variable.setLazy( ->
          todoListWithComplete.get().every ([todo, isCompleted]) -> isCompleted
        )


  @defineLazy 'toggleAllChannelVar', ->
    new Transmitter.ChannelNodes.ChannelVariable()


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .fromSource @todoList
      .toConnectionTarget @toggleAllChannelVar
      .withTransform (todoList) =>
        return null unless todoList?
        Transmitter.Payloads.Variable.setLazy =>
          @createToggleAllChannel()
            .inBackwardDirection()
            .toTargets todoList.map(({isCompletedVar}) -> isCompletedVar).get()


  createToggleAllChannel: ->
    new Transmitter.Channels.SimpleChannel()
      .fromSource @toggleAllCheckboxVar
      .fromSource @toggleAllChangeEvt
      .withTransform (payloads, isCompleted) =>
        isCompletedState = payloads.get(@toggleAllCheckboxVar)
        changed = payloads.get(@toggleAllChangeEvt)
        payload = if changed.get?
          isCompletedState.map((state) -> !state)
        else
          changed

        for key in isCompleted.keys()
          isCompleted.set(key, payload)



class NonBlankTodoListChannel extends Transmitter.Channels.CompositeChannel

  constructor: (@nonBlankTodoList, @todoList) ->

  @defineChannel ->
    new Transmitter.Channels.ListChannel()
      .inForwardDirection()
      .withOrigin @nonBlankTodoList
      .withDerived @todoList


  @defineLazy 'nonBlankTodoChannelVar', ->
    new Transmitter.ChannelNodes.ChannelVariable()


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .fromSource @todoList
      .toConnectionTarget @nonBlankTodoChannelVar
      .withTransform (todoList) =>
        Transmitter.Payloads.Variable.setLazy( =>
          channel = if todoList?
            @createNonBlankTodoChannel(todoList.get())
          else
            new Transmitter.Channels.PlaceholderChannel()
          channel
            .inBackwardDirection()
            .toTarget(@nonBlankTodoList)
        )


  nonBlank = (str) -> !!str.trim()


  createNonBlankTodoChannel: (todos) ->
    if todos.length
      channel = new Transmitter.Channels.SimpleChannel()
      channel.fromSources(todo.labelVar for todo in todos)
      channel.withTransform (labels) ->
        Transmitter.Payloads.List.setLazy ->
          nonBlankTodos =
            todos[i] for label, i in labels.values() when nonBlank(label.get())
          return nonBlankTodos
    else
      new Transmitter.Channels.ConstChannel()
        .withPayload ->
          Transmitter.Payloads.List.setConst([])



class TodoListWithCompleteChannel extends Transmitter.Channels.CompositeChannel

  constructor: (@todoList, @todoListWithComplete) ->


  @defineLazy 'withCompleteChannelVar', ->
    new Transmitter.ChannelNodes.ChannelVariable()


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource @todoListWithComplete
      .toTarget @todoList
      .withTransform (todoListWithComplete) =>
        todoListWithComplete.map ([todo]) -> todo


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .fromSource @todoList
      .toConnectionTarget @withCompleteChannelVar
      .withTransform (todoList) =>
        Transmitter.Payloads.Variable.setLazy( =>
          channel = if todoList?
            @createWithCompleteChannel(todoList.get())
          else
            new Transmitter.Channels.PlaceholderChannel()
          channel
            .inForwardDirection()
            .toTarget(@todoListWithComplete)
        )


  createWithCompleteChannel: (todos) ->
    if todos.length
      channel = new Transmitter.Channels.SimpleChannel()
      channel.fromSources(todo.isCompletedVar for todo in todos)
      channel.withTransform (isCompletedList) ->
        Transmitter.Payloads.List.setLazy ->
          for isCompleted, i in isCompletedList.values()
            [todos[i], isCompleted.get()]
    else
      new Transmitter.Channels.ConstChannel()
        .withPayload ->
          Transmitter.Payloads.List.setConst([])



class SerializedTodoChannel extends Transmitter.Channels.CompositeChannel

  constructor: (@todo, @serializedTodoVar) ->

  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSource @todo.labelVar
      .fromSource @todo.isCompletedVar
      .toTarget @serializedTodoVar
      .withTransform (payloads) =>
        label = payloads.get(@todo.labelVar)
        isCompleted = payloads.get(@todo.isCompletedVar)
        Transmitter.Payloads.Variable.setLazy ->
          {title: label.get(), completed: isCompleted.get()}


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource @serializedTodoVar
      .toTarget @todo.labelVar
      .toTarget @todo.isCompletedVar
      .withTransform (serializedTodo, todoPayload) =>
        todoPayload.set(@todo.labelVar,
          Transmitter.Payloads.Variable.setLazy ->
            serializedTodo.get()?.title
        )
        todoPayload.set(@todo.isCompletedVar,
          Transmitter.Payloads.Variable.setLazy ->
            serializedTodo.get()?.completed
        )



class TodoListPersistenceChannel extends Transmitter.Channels.CompositeChannel

  constructor: (@todoList, @todoListPersistenceVar) ->


  @defineLazy 'todoPersistenceChannelVar', ->
    new Transmitter.ChannelNodes.ChannelVariable()


  @defineLazy 'serializedTodoList', ->
    new Transmitter.Nodes.List()

  @defineLazy 'serializedTodosVar', ->
    new Transmitter.Nodes.Variable()


  @defineChannel ->
    new Transmitter.Channels.VariableChannel()
      .withOrigin @serializedTodosVar
      .withDerived @todoListPersistenceVar
      .withMapOrigin (serializedTodos) ->
        JSON.stringify(serializedTodos)
      .withMapDerived (persistedTodos) ->
        JSON.parse(persistedTodos)


  serializedId = 0
  @defineChannel ->
    new Transmitter.Channels.ListChannel()
      .withOrigin @todoList
      .withMapOrigin (todo) ->
        serializedVar = new Transmitter.Nodes.Variable()
        serializedVar.todo = todo
        id = serializedId++
        serializedVar.inspect = -> "[serializedTodoVar#{id} #{@todo}]"
        return serializedVar
      .withDerived @serializedTodoList
      .withMapDerived (serializedVar) ->
        todo = new Todo()
        serializedVar.todo = todo
        return todo
      .withMatchOriginDerived (todo, serializedTodoVar) ->
        todo == serializedTodoVar.todo
      .withOriginDerivedChannel (todo, serializedTodoVar) ->
        new SerializedTodoChannel(todo, serializedTodoVar)


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource @serializedTodosVar
      .toTarget @serializedTodoList
      .withTransform (serializedTodos) ->
        Transmitter.Payloads.List.setLazy ->
          serializedTodos.get().map ->
            v = new Transmitter.Nodes.Variable()
            id = serializedId++
            v.inspect = -> "[serializedTodoVar#{id} #{@todo}]"
            return v



  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .fromSource @serializedTodoList
      .toConnectionTarget @todoPersistenceChannelVar
      .withTransform (serializedTodoList) =>
        Transmitter.Payloads.Variable.setLazy =>
          if serializedTodoList?
            @createTodoPersistenceChannel(serializedTodoList.get())
          else
            new Transmitter.Channels.PlaceholderChannel()


  createTodoPersistenceChannel: (serializedTodoVars) ->
    if serializedTodoVars.length
      new Transmitter.Channels.CompositeChannel()
        .defineChannel =>
          new Transmitter.Channels.SimpleChannel()
            .inBackwardDirection()
            .fromSource @serializedTodosVar
            .toTargets(serializedTodoVars)
            .withTransform (serializedTodos, serializedTodoVarsPayload) ->
              todos = serializedTodos.get()
              todos = [] unless todos?.length?
              for todoValue, i in todos
                serializedTodoVarsPayload.set(serializedTodoVars[i],
                  new Transmitter.Payloads.Variable.setConst(todoValue))

        .defineChannel =>
          new Transmitter.Channels.SimpleChannel()
            .inForwardDirection()
            .fromSources(serializedTodoVars)
            .toTarget @serializedTodosVar
            .withTransform (serializedTodos) ->
              Transmitter.Payloads.Variable.setLazy ->
                serializedTodos.values().map (v) -> v.get()
    else
      new Transmitter.Channels.ConstChannel()
        .inForwardDirection()
        .toTarget @serializedTodosVar
        .withPayload ->
          Transmitter.Payloads.Variable.setConst([])



window.nonBlankTodoList = new Transmitter.Nodes.List()
nonBlankTodoList.inspect = -> 'nonBlankTodoList'
todoList = new Transmitter.Nodes.List()
todoList.inspect = -> 'todoList'

todoListPersistenceVar =
  new Transmitter.Nodes.PropertyVariable(localStorage, 'todos-transmitter')
todoListPersistenceVar.inspect = -> 'todoListPersistenceVar'
todoListPersistenceChannel =
  new TodoListPersistenceChannel(todoList, todoListPersistenceVar)


todoListWithComplete = new Transmitter.Nodes.List()
todoListWithComplete.inspect = -> 'todoListWithComplete'
todoListWithCompleteChannel =
  new TodoListWithCompleteChannel(todoList, todoListWithComplete)

window.todoListView = new TodoListView($('.todo-list'))
window.newTodoView = new NewTodoView($('.new-todo'))
window.toggleAllCheckboxVar =
  new Transmitter.DOMElement.CheckboxStateVar($('.toggle-all')[0])

window.toggleAllChangeEvt =
  new Transmitter.DOMElement.DOMEvent($('.toggle-all')[0], 'click')

window.toggleAllIsVisibleVar =
  new VisibilityToggleVar($('.toggle-all'))

toggleAllChannel =
  new ToggleAllChannel(todoList, todoListWithComplete, toggleAllCheckboxVar, toggleAllChangeEvt)

toggleAllIsVisibleChannel =
  new Transmitter.Channels.SimpleChannel()
    .inForwardDirection()
    .fromSource todoList
    .toTarget toggleAllIsVisibleVar
    .withTransform (payload) ->
      Transmitter.Payloads.Variable.setLazy ->
        payload.get().length > 0

locationHash = new Transmitter.Browser.LocationHash()
activeFilter = new Transmitter.Nodes.Variable()
activeFilter.inspect = -> 'activeFilter'

locationHashChannel = new Transmitter.Channels.SimpleChannel()
  .inBackwardDirection()
  .fromSource locationHash
  .toTarget activeFilter
  .withTransform (locationHashPayload) ->
    locationHashPayload.map (value) ->
      switch value
        when '#/active' then 'active'
        when '#/completed' then 'completed'
        else 'all'


todoListFooterView = new TodoListFooterView($('.footer'))

nonBlankTodoListChannel = new NonBlankTodoListChannel(nonBlankTodoList, todoList)
todoListViewChannel = new TodoListViewChannel(
  todoList, todoListWithComplete, todoListView, activeFilter)
todoListFooterViewChannel = new TodoListFooterViewChannel(
  todoList, todoListWithComplete, todoListFooterView, activeFilter)



Element::inspect = -> '<' + @tagName + ' ... />'
$.Event::inspect = -> '[$Ev ' + @type + ' ... ]'
Event::inspect = -> '[Ev ' + @type + ' ... ]'

Transmitter.Transmission::loggingFilter = (msg) ->
  msg.match(/activeFilter/)
  # msg.match(/label(Input)?Var|MM/)

Transmitter.Transmission::loggingIsEnabled = no

Transmitter.startTransmission (tr) ->
  todoListView.init(tr)
  nonBlankTodoListChannel.init(tr)
  todoListWithCompleteChannel.init(tr)
  todoListPersistenceChannel.init(tr)
  todoListViewChannel.init(tr)
  todoListFooterViewChannel.init(tr)
  toggleAllChannel.init(tr)
  toggleAllIsVisibleChannel.init(tr)
  newTodoView.init(tr)
  newTodoView.createNewTodoChannel().toTarget(todoList).init(tr)

  locationHashChannel.init(tr)
  locationHash.originate(tr)

  unless todoListPersistenceVar.get()
    todoListPersistenceVar.set(
      JSON.stringify([{title: 'Todo 1', completed: no},
      {title: 'Todo 2', completed: yes}])
    )

  todoListPersistenceVar.originate(tr)

  # todo1 = new Todo().init(tr, label: 'Todo 1', isCompleted: no)
  # todo2 = new Todo().init(tr, label: 'Todo 2', isCompleted: yes)

  # todoList.init(tr, [todo1, todo2])

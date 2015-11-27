import * as Transmitter from 'transmitter';


export default class TodoStorage {
  constructor(name) {
    this.name = name;
    this.todoListPersistenceVar =
      new Transmitter.Nodes.PropertyVariable(localStorage, this.name);
  }

  setDefault(serializedTodos) {
    if (!this.todoListPersistenceVar.get()) {
      this.todoListPersistenceVar.set(JSON.stringify(serializedTodos));
    }
    return this;
  }

  load(tr) {
    return this.todoListPersistenceVar.originate(tr);
  }

  createTodosChannel(todos) {
    return new TodoListPersistenceChannel(todos, this.todoListPersistenceVar);
  }
}


class SerializedTodoChannel extends Transmitter.Channels.CompositeChannel {
  constructor(todo, serializedTodoVar) {
    this.todo = todo;
    this.serializedTodoVar = serializedTodoVar;

    this.defineSimpleChannel()
      .inForwardDirection()
      .fromSources(this.todo.labelVar, this.todo.isCompletedVar)
      .toTarget(this.serializedTodoVar)
      .withTransform(
        ([labelPayload, isCompletedPayload]) =>
          labelPayload.merge(isCompletedPayload).map(
            ([label, isCompleted]) => ({title: label, completed: isCompleted})
          )
      );

    this.defineSimpleChannel()
      .inBackwardDirection()
      .fromSource(this.serializedTodoVar)
      .toTargets(this.todo.labelVar, this.todo.isCompletedVar)
      .withTransform(
        (serializedTodoPayload) =>
          serializedTodoPayload.map( (serialized = {}) => {
            const {title, completed} = serialized;
            return [title, completed];
          }).separate()
      );
  }
}

let serializedId = 0;

class TodoListPersistenceChannel extends Transmitter.Channels.CompositeChannel {

  constructor(todos, todoListPersistenceVar) {
    this.todos = todos;
    this.todoListPersistenceVar = todoListPersistenceVar;
    this.serializedTodoList = new Transmitter.Nodes.List();
    this.serializedTodosVar = new Transmitter.Nodes.Variable();

    this.defineVariableChannel()
      .withOrigin(this.serializedTodosVar)
      .withDerived(this.todoListPersistenceVar)
      .withMapOrigin( (serializedTodos) => JSON.stringify(serializedTodos) )
      .withMapDerived( (persistedTodos) => JSON.parse(persistedTodos) );

    this.defineListChannel()
    .withOrigin(this.todos.todoList)
    .withMapOrigin( (todo) => {
      var id, serializedVar;
      serializedVar = new Transmitter.Nodes.Variable();
      serializedVar.todo = todo;
      id = serializedId++;
      serializedVar.inspect = () =>
        '[serializedTodoVar' + id + ' ' + this.todo + ']';
      return serializedVar;
    })
    .withDerived(this.serializedTodoList)
    .withMapDerived( (serializedVar) => {
      var todo;
      todo = this.todos.create();
      serializedVar.todo = todo;
      return todo;
    })
    .withMatchOriginDerived( (todo, serializedTodoVar) =>
      todo === serializedTodoVar.todo
    )
    .withOriginDerivedChannel( (todo, serializedTodoVar) =>
      new SerializedTodoChannel(todo, serializedTodoVar)
    );

    this.defineSimpleChannel()
      .inBackwardDirection()
      .fromSource(this.serializedTodosVar)
      .toTarget(this.serializedTodoList)
      .withTransform( (serializedTodosPayload) => 
        serializedTodosPayload.toSetList().map(function() {
          var id, v;
          v = new Transmitter.Nodes.Variable();
          id = serializedId++;
          v.inspect = () =>
            '[serializedTodoVar' + id + ' ' + this.todo + ']';
          return v;
        })
      );

    this.todoPersistenceForwardChannelVar =
      new Transmitter.ChannelNodes.DynamicChannelVariable('sources', () =>
        new Transmitter.Channels.SimpleChannel()
        .inForwardDirection()
        .toTarget(this.serializedTodosVar)
        .withTransform(
          (serializedTodosPayloads) => serializedTodosPayloads.flatten()
        )
      );

    this.todoPersistenceBackwardChannelVar =
      new Transmitter.ChannelNodes.DynamicChannelVariable('targets', () =>
        new Transmitter.Channels.SimpleChannel()
        .inBackwardDirection()
        .fromSource(this.serializedTodosVar)
        .withTransform(
          (serializedTodosPayload) =>
            serializedTodosPayload.toSetList().unflatten()
        )
      );

    this.defineSimpleChannel()
      .fromSource(this.serializedTodoList)
      .toConnectionTargets(
        this.todoPersistenceBackwardChannelVar,
        this.todoPersistenceForwardChannelVar
      );
  }
}

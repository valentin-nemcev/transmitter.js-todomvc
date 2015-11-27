import * as Transmitter from 'transmitter-framework/index.es';


export default class TodoStorage {
  constructor(name) {
    this.name = name;
    this.todoListPersistenceValue =
      new Transmitter.Nodes.PropertyValue(localStorage, this.name);
  }

  setDefault(serializedTodos) {
    if (!this.todoListPersistenceValue.get()) {
      this.todoListPersistenceValue.set(JSON.stringify(serializedTodos));
    }
    return this;
  }

  load(tr) {
    return this.todoListPersistenceValue.originate(tr);
  }

  createTodosChannel(todos) {
    return new TodoListPersistenceChannel(todos, this.todoListPersistenceValue);
  }
}


class SerializedTodoChannel extends Transmitter.Channels.CompositeChannel {
  constructor(todo, serializedTodoValue) {
    super();
    this.todo = todo;
    this.serializedTodoValue = serializedTodoValue;

    this.defineSimpleChannel()
      .inForwardDirection()
      .fromSources(this.todo.labelValue, this.todo.isCompletedValue)
      .toTarget(this.serializedTodoValue)
      .withTransform(
        ([labelPayload, isCompletedPayload]) =>
          labelPayload.merge(isCompletedPayload).map(
            ([label, isCompleted]) => ({title: label, completed: isCompleted})
          )
      );

    this.defineSimpleChannel()
      .inBackwardDirection()
      .fromSource(this.serializedTodoValue)
      .toTargets(this.todo.labelValue, this.todo.isCompletedValue)
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

class TodoListPersistenceChannel
extends Transmitter.Channels.CompositeChannel {

  constructor(todos, todoListPersistenceValue) {
    super();
    this.todos = todos;
    this.todoListPersistenceValue = todoListPersistenceValue;
    this.serializedTodoList = new Transmitter.Nodes.List();
    this.serializedTodosValue = new Transmitter.Nodes.Value();

    this.defineValueChannel()
      .withOrigin(this.serializedTodosValue)
      .withDerived(this.todoListPersistenceValue)
      .withMapOrigin( (serializedTodos) => JSON.stringify(serializedTodos) )
      .withMapDerived( (persistedTodos) => JSON.parse(persistedTodos) );

    this.defineListChannel()
    .withOrigin(this.todos.todoList)
    .withMapOrigin( (todo) => {
      const serializedValue = new Transmitter.Nodes.Value();
      serializedValue.todo = todo;
      const id = serializedId++;
      serializedValue.inspect = () =>
        '[serializedTodoValue' + id + ' ' + this.todo + ']';
      return serializedValue;
    })
    .withDerived(this.serializedTodoList)
    .withMapDerived( (serializedValue) => {
      const todo = this.todos.create();
      serializedValue.todo = todo;
      return todo;
    })
    .withMatchOriginDerived( (todo, serializedTodoValue) =>
      todo === serializedTodoValue.todo
    )
    .withOriginDerivedChannel( (todo, serializedTodoValue) =>
      new SerializedTodoChannel(todo, serializedTodoValue)
    );

    this.defineSimpleChannel()
      .inBackwardDirection()
      .fromSource(this.serializedTodosValue)
      .toTarget(this.serializedTodoList)
      .withTransform( (serializedTodosPayload) =>
        serializedTodosPayload.toSetList().map(function() {
          const v = new Transmitter.Nodes.Value();
          const id = serializedId++;
          v.inspect = () =>
            '[serializedTodoValue' + id + ' ' + this.todo + ']';
          return v;
        })
      );

    this.todoPersistenceForwardChannelValue =
      new Transmitter.ChannelNodes.DynamicChannelValue('sources', () =>
        new Transmitter.Channels.SimpleChannel()
        .inForwardDirection()
        .toTarget(this.serializedTodosValue)
        .withTransform(
          (serializedTodosPayloads) => serializedTodosPayloads.flatten()
        )
      );

    this.todoPersistenceBackwardChannelValue =
      new Transmitter.ChannelNodes.DynamicChannelValue('targets', () =>
        new Transmitter.Channels.SimpleChannel()
        .inBackwardDirection()
        .fromSource(this.serializedTodosValue)
        .withTransform(
          (serializedTodosPayload) =>
            serializedTodosPayload.toSetList().unflatten()
        )
      );

    this.defineSimpleChannel()
      .fromSource(this.serializedTodoList)
      .toConnectionTargets(
        this.todoPersistenceBackwardChannelValue,
        this.todoPersistenceForwardChannelValue
      );
  }
}

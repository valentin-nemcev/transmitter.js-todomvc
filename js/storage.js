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
    return new TodoListPersistenceChannel(
      todos, this.todoListPersistenceValue
    );
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
          }).separate(2)
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
    this.serializedTodoValueList = new Transmitter.Nodes.List();
    this.serializedTodoList = new Transmitter.Nodes.List();

    this.defineBidirectionalChannel()
      .withOriginDerived(
        this.serializedTodoList, this.todoListPersistenceValue
      )
      .withTransformOrigin(
        (payload) =>
          payload.toValue().map(
            (serializedTodos) => JSON.stringify(serializedTodos)
          )
      )
      .withTransformDerived(
        (payload) =>
          payload.map(
            (persistedTodos) => JSON.parse(persistedTodos)
          )
          .toList()
      );

    this.defineNestedBidirectionalChannel()
      .withOriginDerived(this.todos.todoList, this.serializedTodoValueList)
      .withMatchOriginDerived( (todo, serializedTodoValue) =>
        todo === serializedTodoValue.todo
      )
      .withMapOrigin( (todo) => {
        const serializedValue = new Transmitter.Nodes.Value();
        serializedValue.todo = todo;
        const id = serializedId++;
        serializedValue.inspect = function() {
          return '[serializedTodoValue' + id + ' ' + this.todo + ']';
        };
        return serializedValue;
      })
      .withMapDerived( (serializedValue) => {
        const todo = this.todos.create();
        serializedValue.todo = todo;
        return todo;
      })
      .withOriginDerivedChannel( (todo, serializedTodoValue) =>
        new SerializedTodoChannel(todo, serializedTodoValue)
      );

    this.defineSimpleChannel()
      .inBackwardDirection()
      .fromSource(this.serializedTodoList)
      .toTarget(this.serializedTodoValueList)
      .withTransform( (serializedTodosPayload) =>
        serializedTodosPayload.updateMatching(
          () => {
            const serializedValue = new Transmitter.Nodes.Value();
            const id = serializedId++;
            serializedValue.inspect = function() {
              return '[serializedTodoValue' + id + ' ' + this.todo + ']';
            };
            return serializedValue;
          }
        ,
        () => true
        )
      );

    this.todoPersistenceForwardChannelValue =
      new Transmitter.ChannelNodes.DynamicListChannelValue(
        'sources',
        (sources) =>
            new Transmitter.Channels.SimpleChannel()
            .inForwardDirection()
            .fromDynamicSources(sources)
            .toTarget(this.serializedTodoList)
            .withTransform(
              (serializedTodosPayloads) => serializedTodosPayloads.flatten()
            )
      );

    this.todoPersistenceBackwardChannelValue =
      new Transmitter.ChannelNodes.DynamicListChannelValue(
        'targets',
        (targets) =>
          new Transmitter.Channels.SimpleChannel()
            .inBackwardDirection()
            .fromSource(this.serializedTodoList)
            .toDynamicTargets(targets)
            .withTransform(
              (serializedTodosPayload) =>
                serializedTodosPayload.unflatten()
            )
      );

    this.defineNestedSimpleChannel()
      .fromSource(this.serializedTodoValueList)
      .toChannelTargets(
        this.todoPersistenceBackwardChannelValue,
        this.todoPersistenceForwardChannelValue
      );
  }
}

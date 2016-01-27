import * as Transmitter from 'transmitter-framework/index.es';


export default class TodoStorage {
  constructor(name) {
    this.name = name;
    this.todoListPersistenceValue =
      new Transmitter.Nodes.PropertyValueNode(localStorage, this.name);
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
          labelPayload.zip(isCompletedPayload).map(
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
          }).unzip(2)
      );
  }
}

class TodoListPersistenceChannel
extends Transmitter.Channels.CompositeChannel {

  constructor(todos, todoListPersistenceValue) {
    super();
    this.todoSet = todos.todoSet;
    this.createTodo = todos.create.bind(todos);

    this.todoList = new Transmitter.Nodes.ListNode();
    this.todoListPersistenceValue = todoListPersistenceValue;
    this.serializedTodoValueList = new Transmitter.Nodes.ListNode();
    this.serializedTodoList = new Transmitter.Nodes.ListNode();

    this.defineBidirectionalChannel()
      .withOriginDerived(this.todoSet, this.todoList)
      .withTransformOrigin(
        (todosPayload) => todosPayload
      );

    this.defineNestedBidirectionalChannel()
      .withOriginDerived(this.todoList, this.serializedTodoValueList)
      .withTransformOrigin(
        (todosPayload) => todosPayload.updateListByIndex(
          () => new Transmitter.Nodes.ValueNode()
        )
      )
      .withTransformDerived(
        (valuesPayload) => valuesPayload.updateListByIndex(
          () => this.createTodo()
        )
      )
      .withOriginDerivedChannel( (todo, serializedTodoValue) =>
        new SerializedTodoChannel(todo, serializedTodoValue)
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
                serializedTodosPayload.unflattenToValues()
            )
      );

    this.defineNestedSimpleChannel()
      .fromSource(this.serializedTodoValueList)
      .toChannelTargets(
        this.todoPersistenceBackwardChannelValue,
        this.todoPersistenceForwardChannelValue
      );

    this.defineSimpleChannel()
      .inBackwardDirection()
      .fromSource(this.serializedTodoList)
      .toTarget(this.serializedTodoValueList)
      .withTransform(
        (serializedTodosPayload) => serializedTodosPayload.updateListByIndex(
          () => new Transmitter.Nodes.ValueNode()
        )
      );

    this.defineBidirectionalChannel()
      .withOriginDerived(
        this.serializedTodoList, this.todoListPersistenceValue
      )
      .withTransformOrigin(
        (payload) =>
          payload
          .joinValues()
          .map(
            (serializedTodos) => JSON.stringify(serializedTodos)
          )
      )
      .withTransformDerived(
        (payload) =>
          payload
          .map(
            (persistedTodos) => JSON.parse(persistedTodos)
          )
          .splitValues()
      );
  }
}

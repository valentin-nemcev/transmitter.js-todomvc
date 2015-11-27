import keycode from 'keycode';

import * as Transmitter from 'transmitter-framework/index.es';


export function getKeycodeMatcher(...keys) {
  return (keypressPayload) =>
    keypressPayload
      .map( (evt) => keys.indexOf(keycode(evt)) >= 0 )
      .noopIf( (isKey) => !isKey );
}


export class VisibilityToggleVar extends Transmitter.Nodes.Variable {

  constructor($element) {
    super();
    this.$element = $element;
  }

  set(state) {
    this.$element.toggle(!!state);
    return this;
  }

  get() {
    return this.$element.is(':visible');
  }
}


export class ClassToggleVar extends Transmitter.Nodes.Variable {

  constructor($element, _class) {
    super();
    this.$element = $element;
    this.class = _class;
  }

  set(state) {
    this.$element.toggleClass(this.class, !!state);
    return this;
  }

  get() {
    return this.$element.hasClass(this.class);
  }
}

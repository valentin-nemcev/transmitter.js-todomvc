import keycode from 'keycode';

import * as Transmitter from 'transmitter-framework/index.es';


export function getKeycodeMatcher(...keys) {
  return (keypressPayload) =>
    keypressPayload
      .map( (evt) => keys.indexOf(keycode(evt)) >= 0 )
      .noOpIf( (isKey) => !isKey );
}


export class VisibilityToggleValue extends Transmitter.Nodes.Value {

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


export class ClassToggleValue extends Transmitter.Nodes.Value {

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

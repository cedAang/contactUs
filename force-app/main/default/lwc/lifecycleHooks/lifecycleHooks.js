import { LightningElement } from 'lwc';

export default class LifecycleHooks extends LightningElement {
constructor() {
    super();
    console.log('Call recieved from constructor');
}

connectedCallback() {
  console.log('Call recieved from connectedCallback'); 
}


disconnectedCallback() {
  console.log('Call recieved from disconnectedCallback')
}


renderedCallback() {
  console.log('Call recieved from renderedCallback');
}
}
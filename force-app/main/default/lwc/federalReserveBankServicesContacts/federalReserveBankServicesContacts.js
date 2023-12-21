import { LightningElement,api,track } from 'lwc';

export default class FederalReserveBankServicesContacts extends LightningElement {
   
   @api number ;
   @api account ;
   @api categories ;
   @track categoryList ;
   @track abaNumber ;
   @track name ;

   connectedCallback(){
        this.categoryList = this.categories;
        this.abaNumber = this.number;
        this.name=this.account;
        console.log('this.name#'+JSON.stringify(this.account));
        console.log('this.abaNumber#'+JSON.stringify(this.number));
        console.log('this.categoryList#'+JSON.stringify(this.categories));
   }
   
}
import { LightningElement,track } from 'lwc';
import getContactDetails from'@salesforce/apex/FRBankServiceContactsController.getContactDetails';
//import getAccountsByAbaNumber from'@salesforce/apex/ContactUsSearchController.getAccountsByAbaNumber';
export default class ContactUsSearchByABA extends LightningElement {
    @track show = false;
    @track spinnerShow = false; 
    @track isError = false ;
    @track errorMessage ;
    @track abaNumber ;
    @track name ;
    @track categoryList ;
    code ;

    handleSearch(){
        this.spinnerShow = true ;
        getContactDetails({abaNumber: this.code}).then(result => {
            if(result.status == 'success'){
               this.name = result.accountName ;
               this.categoryList = result.categoryList ;
               this.show = true; 
               this.isError = false ;
               this.abaNumber = this.code;
            }
            else if(result.status == 'error'){
                this.errorMessage = result.message;
                this.isError = true ;
            }
            this.spinnerShow = false ;
        })
        .catch(error => {
            this.isError = true ;
            this.errorMessage = error.body.message;
            this.spinnerShow = false ;
        })
   }

   handleChangeInput(event){
       this.code = event.detail.value;
   }

}
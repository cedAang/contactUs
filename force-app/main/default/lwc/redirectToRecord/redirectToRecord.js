import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { subscribe, unsubscribe } from 'lightning/empApi';
import { deleteRecord } from 'lightning/uiRecordApi';

export default class RedirectToRecord extends NavigationMixin(LightningElement) {
    @api recordId;
    subscription = {};
    channelName = '/event/RecordRedirectEvent__e';

    connectedCallback() {
        subscribe(this.channelName, -1, (response) => {
            this.subscription = response;
            const eventResponse = JSON.parse(JSON.stringify(response));

            if(eventResponse.data.payload.Clone_Record_Id__c === this.recordId){
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: eventResponse.data.payload.Record_Id__c,
                        objectApiName: 'ContactUsContact__c',
                        actionName: 'view',
                    },
                });

                deleteRecord(eventResponse.data.payload.Clone_Record_Id__c)
            }
        });
    }
   
    disconnectedCallback() {
        if (this.subscription) {
            unsubscribe(this.subscription);
        }
    }

}
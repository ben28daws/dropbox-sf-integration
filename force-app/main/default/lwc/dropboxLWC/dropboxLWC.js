import { LightningElement, api, wire } from 'lwc';
import accessController from '@salesforce/apex/DropboxController.accessController';
import retrieveFilesFromDropbox from '@salesforce/apex/DropboxController.retrieveFilesFromDropbox';
import getRecordAndOpportunities from '@salesforce/apex/OppoController.getRecordAndOpportunities';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';


const columns = [
    { label: 'Accounts and its related opportunities', fieldName: 'name', type: 'text', cellAttributes: { iconName: { fieldName: 'iconName' } } }
];

export default class DocumentTreeView extends LightningElement {
    @api recordId;
    accountRecord;
    opportunities;

    columns = columns;
    treeData = [];
    expandedRows = [];

    @wire(getRecordAndOpportunities, { recordId: '$recordId' })
    wiredData({ data, error }) {
        if (data) {
            this.treeData = this.prepareTreeData(data);
        } else if (error) {
            console.error(error);
        }
    }

    prepareTreeData(data) {
        let treeData = [];
    
        let accountNode = {
            id: data.accountRecord.Id,
            name: data.accountRecord.Name,
            iconName: 'standard:folder',
            _children: []
        };
    
        data.accountDocumentTitles.forEach(attachment => {
            accountNode._children.push({
                id: attachment.Id,
                name: attachment,
                iconName: 'doctype:attachment'
            });
        });
    
        treeData.push(accountNode);
    
        data.opportunities.forEach(opp => {
            let opportunityNode = {
                id: opp.Id,
                name: opp.Name,
                iconName: 'standard:folder',
                _children: []
            };
    
            data.opportunityDocumentTitlesMap[opp.Id].forEach(attachment => {
                opportunityNode._children.push({
                    id: attachment.Id,
                    name: attachment,
                    iconName: 'doctype:attachment'
                });
            });
    
            treeData[0]._children.push(opportunityNode); 
        });
        this.expandedRows = [data.accountRecord.Id];
        return treeData;    
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'expand') {
            this.handleExpand(row);
        }
    }

    handleExpand(row) {
        if (!this.expandedRows.includes(row.id)) {
            this.expandedRows.push(row.id);
        } else {
            this.expandedRows = this.expandedRows.filter(item => item !== row.id);
        }
    }
    handleUpload() {
        accessController({ parentRecordId: this.recordId })
            .then(result => {
                console.log({result})
                this.showToast('Success', result, 'success');
            })
            .catch(error => {
                console.error({error});
                this.showToast('Error', 'Error uploading files: ' + error.body.message, 'error');
            });
    }

    handleRetrieve() {
        retrieveFilesFromDropbox({ parentRecordId: this.recordId })
            .then(result => {
                if(result.startsWith('Error:')){
                    throw new Error(result)
                }

                this.showToast('Success', result, 'success');
            })
            .catch(error => {
                this.showToast('Error', 'Error retrieving files: ' + error.message, 'error');
            });
    
    }
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }

}

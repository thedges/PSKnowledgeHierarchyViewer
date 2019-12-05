import {LightningElement, track} from 'lwc';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import getHierarchy
  from '@salesforce/apex/PSKnowledgeHierarchyUtils.getKnowledgeHierarchy';
import getArticles
  from '@salesforce/apex/PSKnowledgeHierarchyUtils.getKnowledgeArticles';
import searchArticles
  from '@salesforce/apex/PSKnowledgeHierarchyUtils.searchKnowledgeArticles';
import saveOrder from '@salesforce/apex/PSKnowledgeHierarchyUtils.saveOrder';

const columns = [
  {
    label: 'Article #',
    fieldName: 'url',
    type: 'url',
    typeAttributes: {label: {fieldName: 'ArticleNumber'}, target: '_blank'},
    initialWidth: 130,
  },
  {label: 'Title', fieldName: 'Title', type: 'text', sortable: true},
  {
    label: 'Version #',
    fieldName: 'VersionNumber',
    initialWidth: 100,
    type: 'number',
  },
  {
    label: 'Views',
    fieldName: 'ArticleTotalViewCount',
    initialWidth: 80,
    type: 'number',
  },
  {
    label: 'Last Published',
    fieldName: 'LastPublishedDate',
    type: 'date',
    initialWidth: 130,
  },
  {
    label: 'Order',
    fieldName: 'Order',
    type: 'number',
    initialWidth: 80,
    editable: true,
  },
];

export default class PsKnowledgeHierarchyViewer extends LightningElement {
  @track treeList;
  @track data;
  @track columns = columns;
  @track selected = '';
  @track draftValues = [];
  @track showSpinner = false;
  searchStr;
  groupName;
  category;

  connectedCallback () {
    var self = this;

    self.showSpinner = true;

    getHierarchy ().then (result => {
      console.log ('hierarchy=' + result);

      self.treeList = JSON.parse (result);

      getArticles ({groupName: null, category: null})
      .then (result => {
        console.log ('articles=' + result);
        this.showSpinner = false;
        self.saveArticles (result);
      })
      .catch (error => {
        self.handleError (error);
      });
    });
  }


  handleSelect (event) {
    var self = this;

    this.selected = event.detail.name;
    var params = event.detail.name.split ('::');
    this.groupName = params[0];
    this.category = params[1];

    self.showSpinner = true;

    getArticles ({groupName: this.groupName, category: this.category})
      .then (result => {
        console.log ('articles=' + result);
        self.showSpinner = false;
        self.saveArticles (result);
      })
      .catch (error => {
        self.handleError (error);
      });
  }

  saveArticles (result) {
    var data = JSON.parse (result);
    data.forEach (function (item, index) {
      item.url = '/lightning/r/Knowledge__kav/' + item.Id + '/view';
    });

    data.sort (function (a, b) {
      console.log ('>>>>');
      console.log (a.ArticleNumber + ' a.Order=' + a.Order);
      console.log (b.ArticleNumber + ' b.Order=' + b.Order);

      if (a.Order != null && b.Order != null) {
        return a.Order - b.Order;
      } else if (a.Order != null && b.Order == null) {
        return -1;
      } else if (a.Order == null && b.Order != null) {
        return 1;
      } else {
        return a.ArticleNumber - b.ArticleNumber;
      }
    });

    this.data = data;
  }

  handleSearch (event) {
    var self = this;

    if (event.which == 13) {
      console.log ('searchStr=' + event.target.value);
      self.showSpinner = true;

      searchArticles ({searchStr: event.target.value, groupName: this.groupName, category: this.category})
        .then (result => {
          self.showSpinner = false;
          self.saveArticles (result);
        })
        .catch (error => {
          self.handleError (error);
        });
    }
  }

  handleSearchChange (event) {
    var self = this;

    console.log('handleSearchBlur...');
    if (event.target.value == '')
    {
      console.log('search str has been cleared...');
      self.showSpinner = true;

      getArticles ({groupName: this.groupName, category: this.category})
      .then (result => {
        console.log ('articles=' + result);
        self.showSpinner = false;
        self.saveArticles (result);
      })
      .catch (error => {
        self.handleError (error);
      });
    }
  }

  updateColumnSorting (event) {
    var fieldName = event.detail.fieldName;
    console.log ('sort fieldname=' + event.detail.fieldName);
    var sortDirection = event.detail.sortDirection;

    // assign the latest attribute with the sorted column fieldName and sorted direction
    this.sortedBy = fieldName;
    this.sortedDirection = sortDirection;
    this.data = this.sortData (fieldName, sortDirection);
  }

  handleSave (event) {
    var self = this;

    console.log ('handleSave invoked...');
    console.log (
      'event.detail.draftValues=' + JSON.stringify (event.detail.draftValues)
    );
    console.log ('draftValues=' + JSON.stringify (this.draftValues));

    saveOrder ({
      groupName: this.groupName,
      category: this.category,
      values: JSON.stringify (event.detail.draftValues),
    })
      .then (result => {
        console.log ('result=' + result);
        this.draftValues = [];

        getArticles ({
          groupName: this.groupName,
          category: this.category,
        }).then (result => {
          console.log ('articles=' + result);
          self.saveArticles (result);
        });
      })
      .catch (error => {
        self.handleError (error);
      });
  }

  handleError (err) {
    console.log ('error=' + err);
    console.log ('type=' + typeof err);
    
    this.showSpinner = false;

    const event = new ShowToastEvent ({
      title: err.statusText,
      message: err.body.message,
      variant: 'error',
      mode: 'pester',
    });
    this.dispatchEvent (event);
  }
}
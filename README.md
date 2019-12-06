# PSKnowledgeHierarchyViewer
Demo component to show ability for a Knowledge hierarchy viewer

THIS SOFTWARE IS COVERED BY [THIS DISCLAIMER](https://raw.githubusercontent.com/thedges/Disclaimer/master/disclaimer.txt).

## Component Details
This is demo Lightning Web Component for a hierarchy viewer of Salesforce knowledge articles. The component provides the following functionality:

  * Reads in Data Category Groups and Data Categories to show hierarchy tree on left-hand side
  * Any articles not attached to Data Category Group/Category is put in NO_CATEGORY grouping
  * On initial load, it loads all NO_CATEGORY articles and show in table
  * Provides searching:
    * If NO_CATEGORY is selected, it does a full knowledge article search
    * If a specific data category is selected in the hierarchy, it only does search within that data category.
  * Ability to assign an "order" value to articles so those show up at top of list (basic 'pinning')
  
Limitations and options for future enhancements:
  * Currently the component doesn't take in consideration any of the knowledge article visibility settings (Internal App, PKB, Customer, Partner)
  
Here is video of the component:  
![alt text](https://github.com/thedges/PSKnowledgeHierarchyViewer/blob/master/PSKnowledgeHierarchyViewer.gif "Sample Image")

## Component Configuration

This component currently has no configuration properties.

## Component Install and Setup

To use this component:
1. Install the component using the **'Deploy to Salesforce'** button below.
2. Assign the **PSKnowledgeHierarchyViewer** permission set to any user that will use this component.
2. Drag the **psKnowledgeHierarchyViewer** Lightning Component on to your page. That's it.

<a href="https://githubsfdeploy.herokuapp.com">
  <img alt="Deploy to Salesforce"
       src="https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/deploy.png">
</a>


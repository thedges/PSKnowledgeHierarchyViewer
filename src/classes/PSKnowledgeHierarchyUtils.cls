public class PSKnowledgeHierarchyUtils {
    public static Integer P_NONE = 0;
    public static Integer P_CREATE = 1;
    public static Integer P_UPDATE = 2;
    public static Integer P_DELETE = 3;

    public PSKnowledgeHierarchyUtils() {

    }

    @AuraEnabled
    public static String getKnowledgeHierarchy()
    {
        List<Item> hierarchy = new List<Item>();
        Integer lvl = 0;

        List<DescribeDataCategoryGroupResult> describeCategoryResult;
        List<DescribeDataCategoryGroupStructureResult> describeCategoryStructureResult;

        try {
            List<String> objType = new List<String>();
            objType.add('KnowledgeArticleVersion');
            describeCategoryResult = Schema.describeDataCategoryGroups(objType);

            //Creating a list of pair objects to use as a parameter
            //for the describe call
            List<DataCategoryGroupSobjectTypePair> pairs = new List<DataCategoryGroupSobjectTypePair>();

            //Looping through the first describe result to create
            //the list of pairs for the second describe call
            for(DescribeDataCategoryGroupResult singleResult : describeCategoryResult) {
                DataCategoryGroupSobjectTypePair p = new DataCategoryGroupSobjectTypePair();
                p.setSobject(singleResult.getSobject());
                p.setDataCategoryGroupName(singleResult.getName());
                pairs.add(p);
            }
            System.debug('pairs=' + JSON.serialize(pairs));

            //describeDataCategoryGroupStructures()
            describeCategoryStructureResult = Schema.describeDataCategoryGroupStructures(pairs, false);
            System.debug('describeCategoryStructureResult=' + JSON.serialize(describeCategoryStructureResult));

            //Getting data from the result to generate report
            for(DescribeDataCategoryGroupStructureResult singleResult : describeCategoryStructureResult) {
                //Get details of category group
                singleResult.getSobject();
                singleResult.getName();
                singleResult.getLabel();
                singleResult.getDescription();

                Item item = new Item(singleResult.getLabel(), singleResult.getName() + '::' + singleResult.getName());
                hierarchy.add(item);

                System.debug(genPrefix(lvl) + singleResult.getLabel() + ' ' + singleResult.getName());

                //Get the top level categories

                DataCategory [] toplevelCategories = singleResult.getTopCategories();
                for (DataCategory cat : toplevelCategories)
                {
                    processCategory(cat, lvl, singleResult.getName(), item);
                }

                hierarchy.sort();
                System.debug('hierarchy=' + JSON.serializePretty(hierarchy));
            }
            hierarchy.add(0, new Item('NO_CATEGORY', 'NO_CATEGORY'));
            return JSON.serialize(hierarchy);
        }
        catch (Exception e)
        {
            throw new  AuraHandledException(e.getTypeName() + ' - ' + e.getMessage() + ' [Line: ' + e.getLineNumber() + ']');
        }
    }

    private static void processCategory(DataCategory cat, Integer lvl, String groupName, Item item)
    {
        if (cat != null)
        {
            Item iNew;

            if (lvl > 0)
            {
                System.debug(genPrefix(lvl) + cat.getLabel() + ' ' + cat.getName());
                iNew = new Item(cat.getLabel(), groupName + '::' + cat.getName());
                item.addItem(iNew);
            }
            else {
                iNew = item;
            }

            List<DataCategory> childList = cat.getChildCategories();
            if (childList != null && childList.size() > 0)
            {
                for (DataCategory ccat : childList)
                {
                    processCategory(ccat, lvl + 1, groupName, iNew);
                }
            }
        }
    }

    @AuraEnabled
    public static String getKnowledgeArticles(String groupName, String category)
    {
        List<Knowledge__kav> kaList;

        try {

            if (groupName == null || category == null)
            {
                ////////////////////////////////////////////////////////////////////////
                // get ka id list of all articles that have data category assignments //
                ////////////////////////////////////////////////////////////////////////
                Set<Id> dscIdList = new Set<Id>();
                List<Knowledge__DataCategorySelection>  dcsList = [SELECT ParentId from Knowledge__DataCategorySelection];
                for (Knowledge__DataCategorySelection dsc : dcsList)
                {
                    dscIdList.add(dsc.ParentId);
                }
                System.debug('dscIdList=' + JSON.serializePretty(dscIdList));

                //////////////////////////////////////////////////////////////////////////////////////////////
                // retrive articles not in the list above...i.e. articles without data category assignments //
                //////////////////////////////////////////////////////////////////////////////////////////////
                kaList = [SELECT Id, KnowledgeArticleId, ArticleNumber, ArticleTotalViewCount, LastPublishedDate, UrlName, Title, VersionNumber
                                 FROM Knowledge__kav
                                 WHERE IsDeleted = false AND PublishStatus = 'Online' AND Language='en_US' AND
                                            Id NOT IN :dscIdList];
            }
            else {
                ////////////////////////////////////////////////////////////////////////
                // get ka id list of all articles within a defined group and category //
                //   - SOQL cannot use DataCategoryGroupName or DataCategoryname in   //
                //     WHERE clause                                                   //
                ////////////////////////////////////////////////////////////////////////
                Set<Id> dscIdList = new Set<Id>();
                List<Knowledge__DataCategorySelection>  dcsList = [SELECT ParentId, DataCategoryGroupName, DataCategoryName
                               FROM Knowledge__DataCategorySelection];
                for (Knowledge__DataCategorySelection dsc : dcsList)
                {
                    if (dsc.DataCategoryGroupName == groupName && dsc.DataCategoryName == category)
                    {
                        dscIdList.add(dsc.ParentId);
                    }
                }
                System.debug('dscIdList=' + JSON.serializePretty(dscIdList));

                ///////////////////////////////////////////////////////////////////////////////////////
                // retrive articles in the list above...i.e. articles within that group and category //
                ///////////////////////////////////////////////////////////////////////////////////////
                kaList = [SELECT Id, KnowledgeArticleId, ArticleNumber, ArticleTotalViewCount, LastPublishedDate, UrlName, Title, VersionNumber
                                 FROM Knowledge__kav
                                 WHERE IsDeleted = false AND PublishStatus = 'Online' AND Language='en_US' AND
                                            Id IN :dscIdList];

            }

            System.debug('kaList=' + JSON.serializePretty(kaList));
            //return JSON.serialize(kaList);
            return convertKAList(kaList, groupName, category);
        } catch (Exception e) {
            throw new  AuraHandledException(e.getTypeName() + ' - ' + e.getMessage() + ' [Line: ' + e.getLineNumber() + ']');
        }
    }

    @AuraEnabled
    public static String searchKnowledgeArticles(String searchStr, String groupName, String category)
    {
        System.debug('groupName='+ groupName);
        System.debug('category='+ category);

        try {
            String language = 'en_US';
            String objectType = 'KnowledgeArticleVersion';
            String searchText = searchStr;
            Integer maxResults = 30;

            Search.SuggestionOption options = new Search.SuggestionOption();

            Search.KnowledgeSuggestionFilter filters = new Search.KnowledgeSuggestionFilter();

            filters.setLanguage(language);
            filters.setPublishStatus('Online');

            if (groupName != null && category != null) filters.addDataCategory(groupName, category);

            options.setFilter(filters);
            options.setLimit(maxResults);

            Search.SuggestionResults suggestionResults = Search.suggest(searchText, objectType, options);
            List<Search.SuggestionResult> resultList = suggestionResults.getSuggestionResults();

            List<String> kaIdList = new List<String>();
            for (Search.SuggestionResult res : resultList)
            {
                SObject sobj = res.getSOBject();
                System.debug('sobj=' + JSON.serializePretty(sobj));
                kaIdList.add((String)sobj.get('Id'));
            }
            System.debug('kaIdList=' + JSON.serializePretty(kaIdList));

            //////////////////////////////////////////////
            // build list of KA details to return to UI //
            //////////////////////////////////////////////
            List<Knowledge__kav> kaList = [SELECT Id, KnowledgeArticleId, ArticleNumber, ArticleTotalViewCount, LastPublishedDate, UrlName, Title, VersionNumber
                                                  FROM Knowledge__kav
                                                  WHERE IsDeleted = false AND PublishStatus = 'Online' AND Id IN :kaIdList];

            //return JSON.serialize(kaList);
            return convertKAList(kaList, null, null);
        } catch (Exception e) {
            throw new  AuraHandledException(e.getTypeName() + ' - ' + e.getMessage() + ' [Line: ' + e.getLineNumber() + ']');
        }
    }

    private static String convertKAList(List<Knowledge__kav> kaList, String groupName, String category)
    {
        Map<String, Integer> orderMap = new Map<String, Integer>();

        System.debug('convertKAList groupName=' + groupName);
        System.debug('convertKAList category=' + category);

        if (groupName == null || groupName.length() == 0 || groupName == 'NO_CATEGORY') groupName = '-';
        if (category == null || category.length() == 0) category = '-';

        for (KA_Hierarchy_Order__c ho : [SELECT KA_Id__c, Order__c
                                                FROM KA_Hierarchy_Order__c
                                                WHERE Group_Name__c = :groupName AND Category__c = :category])
        {
            orderMap.put(ho.KA_Id__c, ho.Order__c.intValue());
        }


        List<Map<String, Object>> respList = new List<Map<String, Object>>();
        for (Knowledge__kav ka : kaList)
        {
            Map<String, Object> respMap = new  Map<String, Object>();
            respMap.put('Id', ka.Id);
            respMap.put('Title', ka.Title);
            respMap.put('ArticleNumber', ka.ArticleNumber);
            respMap.put('ArticleTotalViewCount', ka.ArticleTotalViewCount);
            respMap.put('LastPublishedDate', ka.LastPublishedDate);
            respMap.put('VersionNumber', ka.VersionNumber);
            respMap.put('UrlName', ka.UrlName);

            if (orderMap.containsKey(ka.Id))
            {
                respMap.put('Order', orderMap.get(ka.Id));
            }
            else {
                respMap.put('Order', null);
            }
            respList.add(respMap);
        }

        return JSON.serialize(respList);
    }

    private static String genPrefix(Integer lvl)
    {
        if (lvl == 0)
        {
            return '';
        } else if (lvl == 1)
        {
            return ' > ';
        } else if (lvl == 2)
        {
            return '  >> ';
        } else if (lvl == 3)
        {
            return '  >>> ';
        } else if (lvl == 4)
        {
            return '  >>>> ';
        } else if (lvl == 5)
        {
            return '  >>>>> ';
        } else if (lvl == 6)
        {
            return '  >>>>>> ';
        }
        else {
            return '  >>>>>>> ';
        }
    }

    private static DataCategory[] getAllCategories(DataCategory [] categories)
    {
        if(categories.isEmpty()) {
            return new DataCategory[] {};
        } else {
            DataCategory [] categoriesClone = categories.clone();
            DataCategory category = categoriesClone[0];
            DataCategory[] allCategories = new DataCategory[] {category};
            categoriesClone.remove(0);
            categoriesClone.addAll(category.getChildCategories());
            allCategories.addAll(getAllCategories(categoriesClone));
            return allCategories;
        }
    }

    @AuraEnabled
    public static void saveOrder(String groupName, String category, String values)
    {
        try {
            List<KA_Hierarchy_Order__c> deleteList = new List<KA_Hierarchy_Order__c>();
            List<Order> reorderList = (List<Order>)JSON.deserialize(values, List<Order>.class);

            if (groupName == null || groupName == 'NO_CATEGORY') groupName = '-';
            if (category == null) category = '-';

            List<KA_Hierarchy_Order__c> orderList = [SELECT Id, KA_Id__c
                                                           FROM KA_Hierarchy_Order__c
                                                           WHERE Group_Name__c = :groupName AND Category__c = :category];
            Map<Id, KA_Hierarchy_Order__c> orderMap = new Map<Id, KA_Hierarchy_Order__c>();
            if (orderList != null && orderList.size() > 0)
            {
                for (KA_Hierarchy_Order__c tmpO : orderList)
                {
                    orderMap.put(tmpO.KA_Id__c, tmpO);
                }
            }

            for (Order o : reorderList)
            {
                KA_Hierarchy_Order__c ho;

                if (orderMap.containsKey(o.Id))
                {
                    ho = orderMap.get(o.Id);
                    if (o.Order == '' || o.Order == null)
                    {
                        KA_Hierarchy_Order__c tmp1 = new KA_Hierarchy_Order__c();
                        tmp1.Id = ho.Id;
                        deleteList.add(tmp1);
                    }
                    else {
                        ho.Order__c = Decimal.valueOf(o.Order);
                    }
                }
                else {
                    ho = new KA_Hierarchy_Order__c();
                    ho.Group_Name__c = groupName;
                    ho.Category__c = category;
                    ho.KA_Id__c = o.Id;
                    ho.Order__c = Decimal.valueOf(o.Order);
                    orderList.add(ho);
                }

            }
            upsert orderList;
            delete deleteList;
        }
        catch (Exception e)
        {
            throw new  AuraHandledException(e.getTypeName() + ' - ' + e.getMessage() + ' [Line: ' + e.getLineNumber() + ']');
        }

    }

    public class Order
    {
        public String Id;
        public String Order;
        public Integer Op;
    }

    public class Item implements Comparable
    {
        public String label;
        public String name;
        public Boolean expanded = false;
        public List<Item> items;

        public Item(String label, String name)
        {
            this.label = label;
            this.name = name;
        }

        public void addItem(Item item)
        {
            if (items == null) items = new List<Item>();
            items.add(item);
        }

        public void addItem(String label, String name)
        {
            Item i = new Item(label, name);
            addItem(i);
        }

        public Integer compareTo(Object compareTo)
        {
            Item otherItem = (Item)compareTo;
            if (label == otherItem.label)
            {
                return 0;
            }
            else if (label < otherItem.label)
            {
                return -1;
            }
            else {
                return 1;
            }
        }
    }
}

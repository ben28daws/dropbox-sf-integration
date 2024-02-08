public class DropboxController {

    @AuraEnabled
    public static void accessController(Id parentRecordId) {
        List<Id> childRecordIds = getChildOpportunityIds(parentRecordId);

        List<Account> accessibleAccounts = [SELECT Id, Name FROM Account WHERE Id = :parentRecordId AND CreatedById = :UserInfo.getUserId() WITH SECURITY_ENFORCED];
        System.debug('Accessible Accounts: ' + accessibleAccounts);

        uploadFilesForRecord(parentRecordId, null);

        for (Id childRecordId : childRecordIds) {
            List<Opportunity> accessibleOpportunities = [SELECT Id, Name FROM Opportunity WHERE Id = :childRecordId AND CreatedById = :UserInfo.getUserId() WITH SECURITY_ENFORCED];
            System.debug('Accessible Opportunities: ' + accessibleOpportunities);

            uploadFilesForRecord(parentRecordId, childRecordId);
        }
    }

    private static List<Id> getChildOpportunityIds(Id parentRecordId) {
        List<Opportunity> opportunities = [SELECT Id FROM Opportunity WHERE AccountId = :parentRecordId];
        List<Id> childRecordIds = new List<Id>();
        for (Opportunity opp : opportunities) {
            childRecordIds.add(opp.Id);
        }
        return childRecordIds;
    }

    private static void uploadFilesForRecord(Id parentRecordId, Id childRecordId) {
        if (childRecordId == null) {
            String recordFolder = DropboxService.getRecordFolder(parentRecordId);
            String folderPath = '/' + recordFolder + '/';

            DropboxService.createFolderInDropbox(folderPath, Label.DropBoxKey);

            List<ContentDocumentLink> links = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :parentRecordId];

            if (!links.isEmpty()) {
                Set<Id> ids = new Set<Id>();
                for (ContentDocumentLink link : links) {
                    ids.add(link.ContentDocumentId);
                }

                List<ContentVersion> versions = [
                    SELECT VersionData, Title, ContentDocumentId, FileExtension 
                    FROM ContentVersion 
                    WHERE ContentDocumentId IN :ids AND IsLatest = true
                ];

                for (ContentVersion attach : versions) {
                    try {
                        String title = attach.Title;
                        String fileExtension = attach.FileExtension.toLowerCase();
                        String versionData = EncodingUtil.base64Encode(attach.VersionData);

                        DropboxService.performUpload(title, fileExtension, versionData, parentRecordId, null);
                    } catch (Exception ex) {
                        System.debug('Error uploading file ' + attach.Title + ': ' + ex.getMessage());
                    }
                }
            }
        }
        else {
            String parentFolder = DropboxService.getRecordFolder(parentRecordId);
            String childFolder = DropboxService.getRecordFolder(childRecordId);
            String folderPath = '/' + parentFolder + '/' + childFolder + '/';

            DropboxService.createFolderInDropbox(folderPath, Label.DropBoxKey);

            List<ContentDocumentLink> links = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :childRecordId];

            if (!links.isEmpty()) {
                Set<Id> ids = new Set<Id>();
                for (ContentDocumentLink link : links) {
                    ids.add(link.ContentDocumentId);
                }

                List<ContentVersion> versions = [
                    SELECT VersionData, Title, ContentDocumentId, FileExtension 
                    FROM ContentVersion 
                    WHERE ContentDocumentId IN :ids AND IsLatest = true
                ];

                for (ContentVersion attach : versions) {
                    try {
                        String title = attach.Title;
                        String fileExtension = attach.FileExtension.toLowerCase();
                        String versionData = EncodingUtil.base64Encode(attach.VersionData);

                        DropboxService.performUpload(title, fileExtension, versionData, parentRecordId, childRecordId);
                    } catch (Exception ex) {
                        System.debug('Error uploading file ' + attach.Title + ': ' + ex.getMessage());
                    }
                }
            }
        }
    }
    
    @AuraEnabled
    public static String retrieveFilesFromDropbox(Id parentRecordId) {
        try {
            String recordTypeName = parentRecordId.getSObjectType().getDescribe().getName();
            String dropboxPath = '/' + recordTypeName + '-' + parentRecordId;

            String dropboxApiUrl = 'https://api.dropboxapi.com/2/files/list_folder';
            HttpRequest req = new HttpRequest();
            req.setEndpoint(dropboxApiUrl);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + Label.DropBoxKey);

            Map<String, Object> requestData = new Map<String, Object>();
            requestData.put('path', dropboxPath);
            System.debug(requestData);
            req.setBody(JSON.serialize(requestData));

            Http http = new Http();
            HttpResponse res = http.send(req);
            System.debug(res);
            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                System.debug(responseMap);
                List<Object> entriesObj = (List<Object>) responseMap.get('entries');
                List<Map<String, Object>> entries = new List<Map<String, Object>>();
                for (Object entry : entriesObj) {
                    entries.add((Map<String, Object>) entry);
                }
                List<String> fileNames = new List<String>();
                System.debug(entries);
                for (Map<String, Object> entry : entries) {
                    String fileName = (String) entry.get('path_display');
                    fileNames.add(fileName);
                }
                System.debug(fileNames);

                uploadFilesAsAttachments(fileNames, parentRecordId);

                return 'Files retrieved and uploaded successfully.';
            } else {
                return 'Error retrieving files from Dropbox. HTTP Status Code: ' + res.getStatusCode();
            }
        } catch (Exception ex) {
            return 'Error: ' + ex.getMessage();
        }
    }
    public static Blob fetchFileContentFromDropbox(String fileName) {
    try {
        String dropboxApiUrl = 'https://content.dropboxapi.com/2/files/download';
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(dropboxApiUrl);
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + Label.DropBoxKey);
        req.setHeader('Dropbox-API-Arg', '{"path":"/' + fileName + '"}');

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            return res.getBodyAsBlob();
        } else {
            System.debug('Error fetching file content from Dropbox. HTTP Status Code: ' + res.getStatusCode());
            return null;
        }
    } catch (Exception ex) {
        System.debug('Error fetching file content from Dropbox: ' + ex.getMessage());
        return null;
      }
    }
    private static void uploadFilesAsAttachments(List<String> fileNames, Id parentRecordId) {
        for (String fileName : fileNames) {
            try {
                Blob fileContent = fetchFileContentFromDropbox(fileName);

                if (fileContent != null) {
                    ContentVersion contentVersion = new ContentVersion();
                    contentVersion.Title = fileName;
                    contentVersion.VersionData = fileContent;
                    insert contentVersion;

                    ContentDocumentLink contentLink = new ContentDocumentLink();
                    contentLink.ContentDocumentId = [SELECT Id FROM ContentVersion WHERE Id = :contentVersion.Id].ContentDocumentId;
                    contentLink.LinkedEntityId = parentRecordId;
                    contentLink.ShareType = 'C';
                    contentLink.Visibility = 'AllUsers';
                    insert contentLink;
                }
            } catch (Exception e) {
                System.debug('Error uploading file ' + fileName + ': ' + e.getMessage());
            }
        }
    }

}
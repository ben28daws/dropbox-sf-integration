public class DropboxService {

    public class Header {
        public String path { get; set; }
        public String mode { get; set; }
        public Boolean autorename { get; set; }
        public Boolean mute { get; set; }
        public Boolean strict_conflict { get; set; }
    }

    public class DropboxFile {
        public String title { get; set; }
        public String fileExtension { get; set; }
        public String versionData { get; set; }
    }

    public static String getRecordFolder(Id recordId) {
        String recordTypeName = recordId.getSObjectType().getDescribe().getName();
        List<ContentDocumentLink> attachments = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :recordId LIMIT 1];
        if (attachments.isEmpty()) {
            return recordTypeName + '-' + recordId;
        } else {
            return recordTypeName + '-' + recordId;
        }
    }

    private static String fileLocation(String file, Id parentRecordId, Id childRecordId) {
        if (childRecordId != null) {
            String parentFolder = getRecordFolder(parentRecordId);
            String childFolder = getRecordFolder(childRecordId);
            return '/' + parentFolder + '/' + childFolder + '/' + file;
        } else {
            String recordFolder = getRecordFolder(parentRecordId);
            return '/' + recordFolder + '/' + file;
        }
    }

    private static String createHeaderArgs(String file, Id parentRecordId, Id childRecordId) {
        Header header = new Header();
        header.path = fileLocation(file, parentRecordId, childRecordId);
        header.mode = 'add';
        header.autorename = true;
        header.mute = false;
        header.strict_conflict = false;
        return JSON.serialize(header);
    }

    @future(callout=true)
    public static void performUpload(String title, String fileExtension, String versionData, Id parentRecordId, Id childRecordId) {
        HttpRequest req = new HttpRequest();
        req.setHeader('Content-Type', 'application/octet-stream');
        req.setMethod('POST');
        
        String endpoint = 'callout:Dropbox/2/files/upload';
        String dropboxApiArg = createHeaderArgs(title + '.' + fileExtension, parentRecordId, childRecordId);
        
        System.debug('Dropbox API URL: ' + endpoint);
        System.debug('Dropbox API Arg: ' + dropboxApiArg);
        
        req.setEndpoint(endpoint);
        req.setBodyAsBlob(EncodingUtil.base64Decode(versionData));
        req.setHeader('Dropbox-API-Arg', dropboxApiArg);
        req.setHeader('Authorization', 'Bearer ' + Label.DropBoxKey);
        Http http = new Http();
        HTTPResponse res = http.send(req);
        System.debug('Response Code: ' + res.getStatusCode());

        if (res.getStatusCode() != 200) {
            System.debug('Error uploading file. HTTP Status Code: ' + res.getStatusCode());
            System.debug('Response Body: ' + res.getBody());
        }
    }

    @future(callout=true)
    public static void createFolderInDropbox(String folderPath, String dropBoxAccessToken) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.dropboxapi.com/2/files/create_folder_v2');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + dropBoxAccessToken);

        if (!folderPath.startsWith('/')) {
            folderPath = '/' + folderPath;
        }
        folderPath = folderPath.removeEnd('/');

        Map<String, Object> folderData = new Map<String, Object>();
        folderData.put('path', folderPath);
        req.setBody(JSON.serialize(folderData));

        Http http = new Http();
        HTTPResponse res = http.send(req);

        System.debug('Create Folder Request: ' + req.getBody());
        System.debug('Create Folder Response Code: ' + res.getStatusCode());
        System.debug('Create Folder Response Body: ' + res.getBody());

        if (res.getStatusCode() != 200) {
            System.debug('Error creating folder. HTTP Status Code: ' + res.getStatusCode());
        }
    }
}
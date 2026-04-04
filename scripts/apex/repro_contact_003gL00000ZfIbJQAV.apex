CreatePortalUserAndNotify.Request r = new CreatePortalUserAndNotify.Request();
r.contactId = '003gL00000ZfIbJQAV';
r.email = 'eyaboudidah00@gmail.com';
r.firstName = 'salma';
r.lastName = 'said';
r.profileId = '00egL0000085KoNQAU';
r.username = 'salma.saidibjqav@gmail.com';
List<CreatePortalUserAndNotify.Result> res = CreatePortalUserAndNotify.createUser(new List<CreatePortalUserAndNotify.Request>{r});
System.debug('RESULT => success=' + res[0].success + ' ; userId=' + res[0].userId + ' ; err=' + res[0].errorMessage);

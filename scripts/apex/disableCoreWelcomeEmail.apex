Network n = [SELECT Id, Name, OptionsSendWelcomeEmail FROM Network WHERE Name = 'Core' LIMIT 1];
System.debug('BEFORE=' + n.OptionsSendWelcomeEmail);
n.OptionsSendWelcomeEmail = false;
update n;
Network n2 = [SELECT Id, Name, OptionsSendWelcomeEmail FROM Network WHERE Id = :n.Id LIMIT 1];
System.debug('AFTER=' + n2.OptionsSendWelcomeEmail);

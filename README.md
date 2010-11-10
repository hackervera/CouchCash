First you need to generate some keys:

make a folder inside your current folder called keys:  
`mkdir keys && cd keys`

then generate your private key:  
`openssl genrsa -out key.priv 1024`

then generate your public key:  
`openssl rsa -in key.priv -out key.pub -pubout`

then cd back to main folder:  
`cd..`

You also need to **edit and rename** your address book.  
`vi address-example.yaml`

To add someone to your address book ask them to send you their public key PEM (**key.pub**) and enter it in the appropriate place:  
Rename address book: `mv address-example.yaml address.yaml`

After you have added keys to your address book, **and renamed it**, run the script to owe someone:  
`ruby owe.rb max 20`

This will create a document on your couchdb instance that will keep track of your debt.  
Edit the **database.yaml** file to select a different couchdb host and/or database.  
You can replicate to other people and share debt information.  
Check out [CouchDB: The Definitive Guide](http://guide.couchdb.org/) for more info on setting up couchdb.  
You can also get free hosting from [CouchOne](http://www.couchone.com/).

To check and see how much you owe to other people, issue this command:  
`ruby account.rb`

That will check all the documents on the network for your records signed with your public id

**Any** questions email [tjgillies@gmail.com](mailto://tjgillies@gmail.com)  
-- Love tyler
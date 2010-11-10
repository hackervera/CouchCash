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

Example Output
==============
`tyler@hosting:~/social$ ruby owe.rb max 10
7d252200-cf40-012d-7fee-4040f2445421
5d88b91d168e9e89112e282be4b47a93b08e829d41dd81858e042f7770f872e76c9986457e7db818cf9c86c9bc313733693f6b60cc002751f612065f5330c43b4819d971137d7b85d64aeb067b85dc0c94b03d71a0cc3a23fec3616c5ac406abfe500d1fa3d8a7a79cecd5bac1b2f7a95b7cb36038f7e79354f0e09e38b6e489
{"ok":true,"id":"7d252200-cf40-012d-7fee-4040f2445421","rev":"1-70d1ef9e89b7ca71fa5296f468704885"}`

This will create a document on your couchdb instance that will keep track of your debt.  
Edit the **database.yaml** file to select a different couchdb host and/or database.  
You can replicate to other people and share debt information.  
Check out [CouchDB: The Definitive Guide](http://guide.couchdb.org/) for more info on setting up couchdb.  
You can also get free hosting from [CouchOne](http://www.couchone.com/).

To check and see how much you owe to other people, issue this command:  
`ruby account.rb`

Example Output
==============
`tyler@hosting:~/social$ ruby account.rb
You owe max (maxoemail@gmail.com) 25`

That will check all the documents on the network for your records signed with your public id

**Any** questions email [tjgillies@gmail.com](mailto://tjgillies@gmail.com)  
-- Love tyler
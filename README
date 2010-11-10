First you need to generate some keys:

make a folder inside your current folder called keys:
`mkdir keys && cd keys`

then generate your private key:
`openssl genrsa -out key.priv 1024`

then generate your public key:
`openssl rsa -in key.priv -out key.pub -pubout`

then cd back to main folder:
`cd..`

You also need to edit and rename your address book.
`vi address-example.yaml`

To add someone to your address book ask them to send you their public key PEM (key.pub) and enter it in the appropriate place:
Rename address book: `mv address-example.yaml address.yaml`


Any questions email [tjgillies@gmail.com](mailto://tjgillies@gmail.com)
-- Love tyler
# How to create the SSL/TLS certification & key
---

1. Create key of domain: **`domain.key`**

    * Create original key with password

        ```
        openssl genrsa -des3 2048 > domain.key.origin
        ```
        
    * Create key without password

        ```
        openssl rsa -in domain.key.origin > domain.key
        ```
        
1. Create certification of domain: **`domain.crt`**

    * Create **scr** by original key woth password

        ```
        openssl reg -new -key domain.key.origin > domain.csr
        ```
    
    * Create **crt** by csr & original key with password

        ```
        openssl x509 -in domain.csr -days 3650 -req -signkey domain.key.origin > domain.crt
        ```
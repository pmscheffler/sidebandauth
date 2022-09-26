# Sideband Authentication via F5 BIG-IP APM

This project is meant to demonstrate sideband authentication functions through leveraging a number of features and functionality within F5's BIG-IP Access Policy Manager (APM). Per-session and per-request policies are used alongside an iRule and HTTP Connector to perform authentication and validation of traffic destined for an API.

### High-level overview of our example process
- Client request is received with a Basic Authorization header
  - Basic Auth header is read from the request and stored
  - APM Session is checked for an existing, valid JWT for this Basic Auth.  If none exists, Basic Auth is sent to an API as POST data, API returns data containing JWT token and expiry if successful
  - JWT is stored in the APM session table with expiry for future comparison
  - Authorization header on the request is set to the JWT token and forwarded
- Client request is received with an OAuth Authorization header
  - Request is forwarded to pool member

The flow is shown in the following diagram:
![API Flowchart](/images/APISidebandAuthFlow.png)


### A few items for clarification
- The generation of the JWT token is beyond the scope of this document but is handled by an external API that rotates and caches tokens in the interest of processing time
- The APM Session table is a secure storage location, protected by the Secure Vault infrastructure on the BIG-IP 
- In order for API calls to work properly with APM and not have requests redirected, Clientless Mode needs to be enabled.  The iRule added this header if it doesn’t exist.
- For this config, we will use both a Per Session Policy (PSP) and a Per Request Policy (PRP) which will allow us to monitor each individual web request.  

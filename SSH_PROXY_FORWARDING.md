# SSH-forwarded download proxies

Some BSSC login aliases may route independent SSH connections to different
login nodes. A reverse proxy forward belongs to the SSH connection that
created it and to the login node reached by that connection. Do not create a
background forward through one connection and assume a later independent
login can use it.

When the operator supplies a local proxy and a remote proxy-environment helper:

1. establish the reverse forward on the same SSH invocation that will perform
   the network operation;
2. source the operator-provided helper only inside that remote command, after
   the forward is active;
3. keep endpoint addresses, ports, credentials and private helper contents out
   of this repository and run records;
4. let the SSH command exit after the bounded download or metadata operation;
5. clear proxy variables before compilation, scheduled execution and MPI work.

If several remote commands need network access, either group them into one
bounded remote shell or give each connection its own forward. A persistent
control connection is safe only when every dependent command is explicitly
multiplexed through that same connection; ordinary new logins are not.

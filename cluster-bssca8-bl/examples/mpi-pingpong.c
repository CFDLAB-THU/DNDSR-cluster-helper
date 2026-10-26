#include <mpi.h>

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(int argc, char **argv)
{
    const int count = 262144;
    int rank = -1;
    int size = 0;
    char host[256];
    double *buffer;

    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);
    gethostname(host, sizeof(host));
    if (size != 2)
        MPI_Abort(MPI_COMM_WORLD, 2);
    buffer = malloc((size_t)count * sizeof(*buffer));
    if (buffer == NULL)
        MPI_Abort(MPI_COMM_WORLD, 3);
    if (rank == 0)
    {
        MPI_Send(buffer, count, MPI_DOUBLE, 1, 7, MPI_COMM_WORLD);
        MPI_Recv(buffer, count, MPI_DOUBLE, 1, 8, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
    }
    else
    {
        MPI_Recv(buffer, count, MPI_DOUBLE, 0, 7, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
        MPI_Send(buffer, count, MPI_DOUBLE, 0, 8, MPI_COMM_WORLD);
    }
    printf("rank=%d size=%d host=%s transfer_bytes=%zu\n", rank, size, host,
           (size_t)count * sizeof(*buffer));
    free(buffer);
    MPI_Finalize();
    return 0;
}

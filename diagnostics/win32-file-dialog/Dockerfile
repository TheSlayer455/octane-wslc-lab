FROM ubuntu@sha256:2198e4c65076e9cb0b3d695219df667c0e3b0072da64ca3c2648aca17dcecaf5 AS build

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates g++-mingw-w64-x86-64 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY diagnostics/win32-file-dialog/main.cpp ./main.cpp
RUN mkdir -p /out \
    && x86_64-w64-mingw32-g++ --version > /out/compiler-version.txt \
    && x86_64-w64-mingw32-g++ -std=c++17 -O2 -Wall -Wextra -Werror \
       -municode -mwindows -static -static-libgcc -static-libstdc++ \
       main.cpp -o /out/FileDialogProbe.exe \
       -lole32 -lshell32 -lcomdlg32 -luuid -luser32 -lgdi32 \
    && x86_64-w64-mingw32-strip /out/FileDialogProbe.exe \
    && sha256sum /out/FileDialogProbe.exe > /out/FileDialogProbe.sha256

FROM scratch AS export
COPY --from=build /out/ /

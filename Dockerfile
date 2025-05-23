# Etapa de build
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /app

# Copiar os arquivos de projeto e restaurar dependências
COPY ./TesteCarga.Api/*.csproj ./TesteCarga.Api/
COPY ./TesteCarga.Core/*.csproj ./TesteCarga.Core/
COPY ./TesteCarga.Infra/*.csproj ./TesteCarga.Infra/
RUN dotnet restore ./TesteCarga.Api/TesteCarga.Api.csproj

# Copiar o restante do código e fazer o build
COPY . .
RUN dotnet publish ./TesteCarga.Api/TesteCarga.Api.csproj -c Release -o /publish

# Etapa de execução
FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /publish
COPY --from=build /publish .

# Definir a porta exposta
EXPOSE 80

# Comando para iniciar a aplicação
ENTRYPOINT ["dotnet", "TesteCarga.Api.dll"]

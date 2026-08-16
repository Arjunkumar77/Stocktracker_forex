# --- Build stage -----------------------------------------------------
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY *.csproj .
RUN dotnet restore

COPY . .
RUN dotnet publish -c Release -o /app

# --- Runtime stage -----------------------------------------------------
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
COPY --from=build /app .

# Render's free tier has a low OS limit on file-watcher (inotify) handles.
# ASP.NET Core watches appsettings.json for live changes by default, which
# hits that limit and crashes on startup. We don't need hot-reload in
# production, so this turns it off.
ENV DOTNET_hostBuilder__reloadConfigOnChange=false

# Render (and most hosts) inject PORT at runtime; Program.cs already
# reads it and binds to 0.0.0.0:$PORT automatically.
ENTRYPOINT ["dotnet", "GoldForexApi.dll"]

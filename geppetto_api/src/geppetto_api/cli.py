def start():
    import uvicorn
    uvicorn.run("geppetto_api.main:app", reload=True)
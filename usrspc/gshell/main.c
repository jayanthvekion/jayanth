/*
 *
 * Copyright (c) 2023 Yuvraj Sakshith <ysakshith@gmail.com>
 *
 */


#include "stdio.h"
#include "unistd.h"
#include "string.h"

void gshell_init(){
    printf("NovaOS v1.0.0\n");
}

void gshell_process_command(char* command){
    if(strcmp(command, "hello") == 0){
        printf("Hello from NovaOS!\n");
        return;
    }
    if(exec(command) < 0){
        printf("couldnt open file\n");
    }
}

int main(){

    gshell_init();

    while(1){
        printf("nova> ");
        
        char command[30];
        gets(command);

        gshell_process_command(command);
    }

    while(1){}

    return 0;
}
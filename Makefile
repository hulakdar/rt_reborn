CC		= gcc
CFLAGS	= -Wall -Wextra -g
FILES	= cl_wrapper noc_file_dialog main
OBJ		= $(addprefix obj/, $(addsuffix .o, $(FILES)))
INCL 	= -I /Library/Frameworks/SDL2.framework/Headers -I inc 
LIBS	= -L. /Library/Frameworks/SDL2.framework/SDL2 -framework OpenCL -L ~/.brew/lib $(shell pkg-config --cflags --libs gdk-pixbuf-2.0 gtk+-2.0) -framework AppKit
NAME	= RT

all: $(NAME)

$(NAME): $(OBJ)
	@$(CC) $(OBJ) $(CFLAGS) $(LIBS) -o $(NAME)
	@echo "Binary is done! 🖥"

obj/noc_file_dialog.o: src/noc_file_dialog.mm
	@$(CC) -c $^ -o $@ $(CFLAGS) $(INCL)

obj/%.o: src/%.c
	@$(CC) -c $^ -o $@ $(CFLAGS) $(INCL)
clean:
	@rm -f $(OBJ)
	@echo "Cleaned the objects! ❌"
fclean: clean
	@rm -f $(NAME)
	@echo "Cleaned the binary! ☠️"
re: fclean all
	
.PHONY: clean fclean re


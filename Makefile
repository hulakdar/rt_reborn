CC		= gcc
CFLAGS	= -Wall -Wextra -g
FILES	= cl_wrapper noc_file_dialog main
OBJ		= $(addprefix obj/, $(addsuffix .o, $(FILES)))
INCL 	= -I /Library/Frameworks/SDL2.framework/Headers -I inc -I ~/.brew/include/gtk-2.0/ -I ~/.brew/include/gio-unix-2.0/ -I ~/.brew/include/glib-2.0 -I ~/.brew/Cellar/glib/2.56.0/lib/glib-2.0/include/  -I ~/.brew/Cellar/cairo/1.14.12/include/cairo/ -I ~/.brew/Cellar/pango/1.42.0/include/pango-1.0/ -I ~/.brew/Cellar/gtk+/2.24.32_1/lib/gtk-2.0/include/ -I ~/.brew/Cellar/gdk-pixbuf/2.36.11/include/gdk-pixbuf-2.0/ -I ~/.brew/Cellar/atk/2.28.1/include/atk-1.0/
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


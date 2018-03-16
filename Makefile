CC		= clang
CFLAGS	= -Wall -Wextra -g
FILES	= main cl_wrapper
OBJ		= $(addprefix obj/, $(addsuffix .o, $(FILES)))
INCL 	= -I /Library/Frameworks/SDL2.framework/Headers -I inc
LIBS	= -L. /Library/Frameworks/SDL2.framework/SDL2 -framework OpenCL
NAME	= RT

all: $(NAME)

$(NAME): $(OBJ)
	@$(CC) -o $(NAME) $(OBJ) $(CFLAGS) $(LIBS)
	@echo "Binary is done! 🖥"
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


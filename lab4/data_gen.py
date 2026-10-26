import os 
import random
import string
import sys



def generate_random_binary(bitwidth, length):
    """
    Generate a random binary string of length `length` and bitwidth `bitwidth`
    """
    data = []
    # generate random data range from 0 to 2^bitwidth - 1
    data = [random.randint(0, 2**bitwidth - 1) for _ in range(length)]
    # convert to binary string and fill with 0s to make it `bitwidth` long
    data = [bin(d)[2:].zfill(bitwidth) for d in data]
    # join the list of binary strings into one string
    data = "\n".join(data)
    return data


def separate_din_dout(file):
    """
    Separate the input and output data
    """
    din = []
    dout = []
    with open(file, "r") as f:
        for line in f:
            line = line.strip()
            if line.startswith("din"):
                din.append(line.split("=")[1].strip())
            elif line.startswith("dout"):
                dout.append(line.split("=")[1].strip())
    return din, dout
            



if __name__ == "__main__":

    #take in the command line arguments
    mode = str(sys.argv[1])
    
    if mode == "gen_data":
        # Generate a random binary string of length 1000 and bitwidth 32
        with open(os.path.join(os.path.dirname(__file__), "data.txt"), "w") as f:
            f.write(generate_random_binary(32, 1024))
    else:
        #load in the data from the data.txt file
        with open(os.path.join(os.path.dirname(__file__), "data.txt"), "r") as f:
            data = f.read()
        # convert the data to a list of hex strings with 32 bits 
        # data = [hex(int(d, 2))[2:].zfill(8) for d in data.split("\n")]
        data = [hex(int(d, 2))[2:] for d in data.split("\n")]

        # write the data to the data.log file
        with open(os.path.join(os.path.dirname(__file__), "data.log"), "w") as f:
            f.write("\n".join(data))
        
        # Separate the input and output data
        din, dout = separate_din_dout(os.path.join(os.path.dirname(__file__), "axis_data_fifo.log"))
        # Write the input data to a file
        with open(os.path.join(os.path.dirname(__file__), "din.log"), "w") as f:
            f.write("\n".join(din))
        # Write the output data to a file
        with open(os.path.join(os.path.dirname(__file__), "dout.log"), "w") as f:
            f.write("\n".join(dout))
        #compare din and dout if they are the same print Passed! else print Failed!
        if din == dout and din == data:
            print("Passed!")
        else:
            print("Failed!")
            print("Data written to the FIFO is not the same as the data read from the FIFO")
        



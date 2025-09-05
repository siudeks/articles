
# Memory leak with popular Stream.toList()

Streams are a very popular method of data processing, especially since they promise to provide more and more methods that allow you to operate on sets in a predictable way. However, are they completely safe? In this example, we will show that closing resources produced by streams is a subtle difference that is hard to catch in a program, and you need to pay attention to it to avoid losing resources.

First proof: a test for opening and closing files does not lose resources.

Second proof: a test for opening files causes resource loss if we do not close them.

Third proof: using streams based on files in a way similar to using memory-based streams leads to file leaks.

Conclusions and suggestions for the future.

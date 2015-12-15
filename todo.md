* Find API required for adapters
  * http://hexdocs.pm/ecto/Ecto.Adapter.html * needs at least these functions.
* Write tests to determine API correctness
  * We get these for free from Ecto!
* Make tests pass (using wrapper? maybe)
* Cypher Query Builder
  * each function in Cypher (find, where, etc.) has a corresponding method (limited to start)
  * methods take a struct of previous query elements

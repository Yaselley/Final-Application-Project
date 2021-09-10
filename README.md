# PAF
## Final Application Project - Autonomous Growth and Task-distribution in Hierarchical Organisations

This project aims to develop a multi-agent model for simulating the progressive growth, and possible shrinkage, of hierarchical organisations. Moreover, it aims to study the success rate of various agent coordination processes while the hierarchy's topology changes (growth/shrinkage). This project is supervised by researchers from several disciplines and universities and part of a larger research project. 

The organisation consists of two agent types: workers (in blue in the Fig.) and managers (in white). As workers are added progressively, the hierarchy has to grow (adding and interconnecting managers) so as to ensure one manager for every C workers; and one manager for every C managers (Cf. Fig. above). Similarly, the hierarchy shrinks when workers are removed.

The targeted coordination process aims to distribute a number of task types, equally amongst all the agents located at the bottom of the hierarchy (the workers). Initially, workers pick tasks randomly. Then, managers mediate the coordination process, by assessing the current state of all their subordinates (child nodes in the hierarchy) and sending them control signals (feedback) on how to change their task selections. The process iterates, up and down through the hierarchy, leading to a convergent state, or to oscillatory or divergent behaviour. Ideally, the hierarchical organisation converges to the desired state (equal task distribution amongst workers), as the number of workers (and the organisation's hierarchical topology) changes.

![alt text](https://paf.telecom-paris.fr/sites/paf.telecom-paristech.fr/files/images/fig1_0.png)

System Model and Expected behaviour
Growth model
The simulation starts with zero workers. The number of children per parent C is given as input (ex : C=2 in Fig.1). Then, at each iteration, one worker is added (e.g., by clicking an 'Add' button) and the necessary manager(s) and interconnection(s) are added accordingly, to ensure that each child (worker or manager) has one and only one parent (manager); and that no parent (manager) has more than C children (workers or managers). The model can be extended to add several corkers at one (number given as input by the user).

### Shrinkage model
At each iteration, one worker is deleted (e.g. by clicking a 'Delete' button) and the topology of managers is updated accordingly. If a manager has no more children, then it should be deleted. The topology may also be reshuffled (e.g. via a 'Rebalance' button) so as to better distribute children amongst parent branches. The model can be extended to delete several workers at once (number given as input by the user).

### Coordination Model for Task Distribution
The number of task types is given as input. Task types should be distributed equally amongst workers. E.g. for 14 workers and 2 task types, 7 workers should perform the first task type and the other 7 workers the other task type. When tasks cannot be distributed exactly, we aim to reach a distribution that is as equal as possible (e.g. for 14 workers and 3 task types we aim to get 2 task types performed by 5 workers each and 1 task type performed by 4 workers).


* Each parent collects state information about their children (which tasks they have selected);
* Each parent compares its children's state information with the desired objective, which it obtains from their own parent, or from the user's input (if they are the top manager and have no parent);
* Each parent returns a control directive to its children, indicating how to change their selected tasks - this control directive is used by child managers as an objective to achieve via their own children; it is used by workers to decide whether to change their selected task and how;
* Workers use the control signal from their parent managers to update their selected tasks.


#include <linux/kernel.h>
#include <linux/slab.h>
#include <linux/cpu.h>

static int get_first_sibling(unsigned int cpu)
{
	unsigned int ret;

	ret = cpumask_first(topology_sibling_cpumask(cpu));
	if (ret < nr_cpu_ids)
		return ret;
	return cpu;
}

/*
 * Take a map of online CPUs and the number of available interrupt vectors
 * and generate an output cpumask suitable for spreading MSI/MSI-X vectors
 * so that they are distributed as good as possible around the CPUs.  If
 * more vectors than CPUs are available we'll map one to each CPU,
 * otherwise we map one to the first sibling of each socket.
 *
 * If there are more vectors than CPUs we will still only have one bit
 * set per CPU, but interrupt code will keep on assining the vectors from
 * the start of the bitmap until we run out of vectors.
 */
int irq_create_affinity_mask(struct cpumask **affinity_mask,
		unsigned int nr_vecs)
{
	if (nr_vecs == 1) {
		*affinity_mask = NULL;
		return 0;
	}

	*affinity_mask = kzalloc(cpumask_size(), GFP_KERNEL);
	if (!*affinity_mask)
		return -ENOMEM;

	if (nr_vecs >= num_online_cpus()) {
		cpumask_copy(*affinity_mask, cpu_online_mask);
	} else {
		unsigned int cpu;

		for_each_online_cpu(cpu) {
			if (cpu == get_first_sibling(cpu))
				cpumask_set_cpu(cpu, *affinity_mask);

			if (--nr_vecs == 0)
				break;
		}
	}

	return 0;
}

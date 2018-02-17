<template>
    <div v-bind:class="classObject" @mousedown="select" data-id="cell.id">

        <template v-if="isEdit">
            <button type="button" class="close" aria-label="Close" @click="cell.destruct()">
                <span aria-hidden="true">&times;</span>
            </button>

            <span class="DataLabel">
                <input maxlength="20" v-model="cell.name" placeholder="Name..."/>
            </span>
            <span class="DataValue">
                <template v-if="isLargeItem">
                    <textarea v-model="cell.expr" class="DataInput"></textarea>
                </template>
                <template v-else>
                    <input type="text" placeholder="Value" v-model="cell.expr" class="DataInput" autofocus/>
                    
                    <template v-if="cell.isArrResult">
                        <!-- TODO -->
                        <!-- <Cell-List v-bind:group="cell._result"
                            ></Cell-List> -->
                            <!-- v-bind:parent="this.value[0].parent_group" -->
                    </template>
                    <template v-else>
                        <p>{{ cell.toString() }}</p>
                    </template>
                        
                </template>
            </span>
        </template>
        <template v-else>

            <label class="DataLabel">{{ cell.name }}</label>
            <span class="DataValue">

                    <!-- Auto-reflow to next line due to div -->
                    <template v-if="cell.isArrResult">
                        <!-- <Cell-List v-bind:cells="cell._result"
                            ></Cell-List> -->
        <!-- v-bind:parent="this.value[0].parent_group" -->
                    </template>
                    <template v-else>
                        {{ cell.toString() }}
                    </template>

            </span>
        </template>

    </div>
</template>

<script lang="ts">
import Vue from "vue";
import {Value} from "../engine/engine";
import * as constants from "../constants"

export default Vue.component('Cell', {
    name: 'Cell',
    props: {
        'cell': {type: Value},
    },
    data: () => {
        return {
            'constants': constants
        }
    },
    computed: {
        result: function() : string {
            return this.cell.evaluate()
        },
        isLargeItem: function() : boolean {
            // TODO: Check if text is long or not
            if(this.cell.type === "object"){
                return true;
            } else if(this.cell.type === "text" && this.cell.expr.length > 100){
                return true;
            }
            // return false;
            return this.cell.expr.toString().length > 50;
        },
        isEdit: function() : boolean {
            // return isEditMode(this.selected, this.orderIndex)
            return this.$store.state.editCell === this.cell;
        },
        classObject: function() : object {
            // var typeClass = "DataType--" + this.cell.type;
            var typeClass = "DataType--" + this.cell.result_type;
            var cellClass = "CellType--" + this.cell.type;
            // this.index is relative within a group.
            let classes: {[index: string]: any} =  {
                "DataRow": true,
                "DataRow--large": this.isLargeItem,
                "edit": this.isEdit,
                "list-group-item": true,
            }
            classes[typeClass] = true;
            classes[cellClass] = true;
            return classes;
        },
    },
    methods: {
        select: function(event: Event) {
            // @ts-ignore:
            if(this.isEdit) {
                // Hide this mousedown event from selector so our input boxes can be edited.
                event.stopPropagation();
            }
            this.$store.commit("setEdit", this.cell);
            console.log("Setting edit");
        }
    },
    watch: {
        isEdit: function (val) {
            if(val) {
                let el = this.$el;
                // Wait till after element is added.
                setTimeout(function() {
                    // el.querySelector('.DataValue .DataInput').focus();
                }, 100);
            }
       }
    }
});
</script>

<style>
</style>